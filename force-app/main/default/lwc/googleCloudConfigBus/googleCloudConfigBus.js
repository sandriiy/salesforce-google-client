import generateConfigId from '@salesforce/apex/GoogleCloudConfigController.generateConfigId';
import pushConfig from '@salesforce/apex/GoogleCloudConfigController.pushConfig';
import pullConfig from '@salesforce/apex/GoogleCloudConfigController.pullConfig';
import removeConfig from '@salesforce/apex/GoogleCloudConfigController.removeConfig';

const DEFAULT_POLL_INTERVAL_MS = 250;
const DEFAULT_TIMEOUT_MS = 8000;

function safeJsonStringify(value) {
	try { return JSON.stringify(value); } catch (e) { return null; }
}

function safeJsonParse(value) {
	try { return JSON.parse(value); } catch (e) { return null; }
}

export async function startConfigSession(payload) {
	const configId = await generateConfigId();

	const payloadJson = safeJsonStringify(payload);
	if (payloadJson === null) {
		throw new Error('Unable to serialize payload.');
	}

	await pushConfig({ configId, payloadJson });

	const subscription = {
		unsubscribe: () => removeConfig({ configId }).catch(() => {})
	};

	return { configId, subscription };
}

export function requestConfig(configId, onConfigReceived) {
	let isActive = true;
	let timerId;
	const startedAt = Date.now();

	const stop = () => {
		isActive = false;
		if (timerId) {
			window.clearTimeout(timerId);
			timerId = null;
		}
	};

	const tick = async () => {
		if (!isActive) return;

		try {
			const payloadJson = await pullConfig({ configId });

			const payload = safeJsonParse(payloadJson);
			if (typeof onConfigReceived === 'function') {
				onConfigReceived(payload);
			}

			stop();
			return;
		} catch (e) {}

		if (Date.now() - startedAt >= DEFAULT_TIMEOUT_MS) {
			stop();
			return;
		}

		timerId = window.setTimeout(tick, DEFAULT_POLL_INTERVAL_MS);
	};

	tick();
	return { unsubscribe: stop };
}

export function stopConfigSession(subscription) {
	if (subscription?.unsubscribe) {
		try { subscription.unsubscribe(); } catch (e) {}
	}
}