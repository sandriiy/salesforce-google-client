import QUICK_SETUP_LINK from '@salesforce/label/c.GoogleClientQuickSetupLink';

export const DOCS_BASE_URL = 'https://sandriiy.github.io/salesforce-google-client';
const GEMINI_SETUP_URL = 'https://ai.google.dev/gemini-api/docs/api-key';
const AGENT_SETUP_URL = 'https://cloud.google.com/vertex-ai/generative-ai/docs/start';

export const CONFIG_SECTION = {
    drive: 'drive',
    ai: 'ai'
};

export const CONFIG_VIEW = {
    main: 'main',
    advanced: 'advanced'
};

export const CONFIG_CONTEXT_MESSAGE_TYPE = {
    context: 'context',
    ready: 'ready'
};

const GUIDES = {
    'drive:admin': {
        title: 'Quick Setup',
        subtitle: 'Google Drive · Admin setup',
        steps: [
            { title: 'Generate certificate', text: 'Create a Service Account → Create a new Key → Convert it into a certificate.' },
            { title: 'Upload to Salesforce', text: 'Setup → Certificate and Key Management.' },
            { title: 'Enter details', text: 'Specify the Service Account email &amp; uploaded certificate name.' }
        ],
        button: { label: 'Open Quick Setup Guide', url: QUICK_SETUP_LINK }
    },
    'drive:developer': {
        title: 'Quick Setup',
        subtitle: 'Google Drive · Developer setup',
        steps: [
            { title: 'Generate certificate', text: 'Create a Service Account → Create a new Key → Convert it into a certificate.' },
            { title: 'Upload to Salesforce', text: 'Setup → Certificate and Key Management.' },
            { title: 'Implement authorizer', text: 'Create an Apex class that implements <b>GoogleAuthorizer</b> and returns an access token.' }
        ],
        button: { label: 'Open Quick Setup Guide', url: QUICK_SETUP_LINK }
    },
    'ai:gemini': {
        title: 'Gemini Quick Setup',
        subtitle: 'Gemini Developer API',
        steps: [
            { title: 'Open Google AI Studio', text: 'Create or select the project that will be used for your Gemini Developer API requests.' },
            { title: 'Generate an API key', text: 'Create a Gemini API key in Google AI Studio and copy it into the <b>Gemini API Key</b> field.' },
            { title: 'Choose the model and validate', text: 'Set the model name, then save and validate the configuration. Turn analysis on afterwards under Advanced → AI Intelligence.' }
        ],
        button: { label: 'Open Gemini Setup Guide', url: GEMINI_SETUP_URL }
    },
    'ai:agent': {
        title: 'Agent Platform Quick Setup',
        subtitle: 'Agent Platform (ex-Vertex AI)',
        steps: [
            { title: 'Enable Agent Platform', text: 'Open the target Google Cloud project, ensure billing is active, and enable Agent Platform API (ex-Vertex AI API) for that project.' },
            { title: 'Reuse the existing Drive service account', text: 'Grant <b>Vertex AI User</b> role (Agent Platform) access to the same service account already used for Google Drive in this org. No new service account is required.' },
            { title: 'Enter project details and validate', text: 'Specify the Project ID, Location, and Model Name, then save and validate the configuration. Turn analysis on afterwards under Advanced → AI Intelligence.' }
        ],
        button: { label: 'Open Agent Platform Setup Guide', url: AGENT_SETUP_URL }
    },
    'advanced:fileManagement': {
        title: 'File Management',
        subtitle: 'Advanced settings',
        steps: [
            { title: 'Preview and upload', text: 'Turn file previews off, or let large uploads go straight from the browser to Google Drive for noticeably faster uploads.' },
            { title: 'Open in Google Drive', text: 'Let file owners open a file in Google Drive with temporary view access to that one file.' },
            { title: 'Limits and domain', text: 'Set the maximum preview size, how many files are deleted at a time, and the domain public links are restricted to.' }
        ],
        button: { label: 'Read about File Management', url: `${DOCS_BASE_URL}/config/advanced/file-management/` }
    },
    'advanced:userInterface': {
        title: 'User Interface',
        subtitle: 'Advanced settings',
        steps: [
            { title: 'Choose columns', text: 'Pick which columns File Explorer shows and drag them into the order you want. Title always stays first.' },
            { title: 'Add your own field', text: 'Any Google File Version field can become a column by entering its API name.' },
            { title: 'Nothing else changes', text: 'Leaving the selection untouched keeps the standard layout every org has today.' }
        ],
        button: { label: 'Read about User Interface', url: `${DOCS_BASE_URL}/config/advanced/user-interface/` }
    },
    'advanced:aiIntelligence': {
        title: 'AI Intelligence',
        subtitle: 'Advanced settings',
        steps: [
            { title: 'Turn analysis on', text: 'AI Analytics needs a connected and validated provider. Set it up under Gemini &amp; Agent Platform first, then switch it on here.' },
            { title: 'Shape the answers', text: 'Adjust the summary and question prompts, and how long an answer may be.' },
            { title: 'Label files automatically', text: 'Describe each Google Drive label in plain language and Google Client assigns the best match to new files when it is confident enough.' }
        ],
        button: { label: 'Read about AI Intelligence', url: `${DOCS_BASE_URL}/config/advanced/ai-intelligence/` }
    },
    'advanced:safetyCustomization': {
        title: 'Safety & Customization',
        subtitle: 'Advanced settings',
        steps: [
            { title: 'Pick a safety mode', text: 'Standard suits most organizations. Strict refuses more, Relaxed screens answers only, Off removes the barrier entirely.' },
            { title: 'Bring your own guard', text: 'Replace the shipped inspection with an Apex class when you have content rules of your own.' },
            { title: 'Applies to every prompt', text: 'These settings cover summaries, questions, and labeling alike.' }
        ],
        button: { label: 'Read about Safety & Customization', url: `${DOCS_BASE_URL}/config/advanced/safety-customization/` }
    }
};

const buildGuideKey = (context) => {
    if (!context) {
        return null;
    }

    if (context.view === CONFIG_VIEW.advanced) {
        return context.tab ? `advanced:${context.tab}` : null;
    }

    return context.section && context.variant ? `${context.section}:${context.variant}` : null;
};

const resolveSetupGuide = (context) => {
    const guideKey = buildGuideKey(context);
    const guide = guideKey ? GUIDES[guideKey] : null;
    if (!guide) {
        return null;
    }

    return {
        key: guideKey,
        title: guide.title,
        subtitle: guide.subtitle,
        steps: guide.steps.map((step, index) => ({
            key: `${guideKey}-${index}`,
            number: index + 1,
            title: step.title,
            text: step.text
        })),
        button: guide.button
    };
};

export { resolveSetupGuide, buildGuideKey };
