/**
 * @description Test class for base TriggerHandler class
 * @author {@link [Kevin OHara](https://github.com/kevinohara80)}
 * @since 2013
 * @author {@link [David Schach](https://github.com/dschach)}
 * @since 2021 Update, add new methods
 * @since 2023-02-08 Update assert methods to Assert class
 * @group Trigger Handler
 * @see [GitHub](https://github.com/dschach/salesforce-trigger-handler)
 * @see TriggerHandler
 */
@isTest
private class GTriggerHandlerTest {
	private static String lastMethodCalled;
	private static GTriggerHandlerTest.TestHandler handler;

	static {
		handler = new GTriggerHandlerTest.TestHandler();
		// override its internal trigger detection
		handler.isTriggerExecuting = true;
	}

	// contexts tests

	@isTest
	private static void testBeforeInsert() {
		beforeInsertMode();
		handler.run();
		Assert.areEqual('beforeInsert', lastMethodCalled, 'last method should be beforeInsert');
		Assert.areEqual(System.TriggerOperation.BEFORE_INSERT, handler.triggerEvent, 'triggerEvent should be set to current context');
	}

	@isTest
	private static void testBeforeUpdate() {
		beforeUpdateMode();
		handler.run();
		Assert.areEqual('beforeUpdate', lastMethodCalled, 'last method should be beforeUpdate');
	}

	@isTest
	private static void testBeforeDelete() {
		beforeDeleteMode();
		handler.run();
		Assert.areEqual('beforeDelete', lastMethodCalled, 'last method should be beforeDelete');
	}

	@isTest
	private static void testAfterInsert() {
		afterInsertMode();
		handler.run();
		Assert.areEqual('afterInsert', lastMethodCalled, 'last method should be afterInsert');
	}

	@isTest
	private static void testAfterUpdate() {
		afterUpdateMode();
		handler.run();
		Assert.areEqual('afterUpdate', lastMethodCalled, 'last method should be afterUpdate');
	}

	@isTest
	private static void testAfterDelete() {
		afterDeleteMode();
		handler.run();
		Assert.areEqual('afterDelete', lastMethodCalled, 'last method should be afterDelete');
	}

	@isTest
	private static void testAfterUndelete() {
		afterUndeleteMode();
		handler.run();
		Assert.areEqual('afterUndelete', lastMethodCalled, 'last method should be afterUndelete');
	}

	@isTest
	private static void testNonTriggerContext() {
		try {
			handler.run();
			Assert.isTrue(false, 'the handler ran but should have thrown an exception');
		} catch (GTriggerHandler.TriggerHandlerException te) {
			Assert.areEqual(GTriggerHandler.ERROR_TRIGGERCONTEXT, te.getMessage(), 'the exception message should match');
		} catch (Exception e) {
			Assert.isTrue(false, 'the exception thrown was not expected: ' + e.getTypeName() + ': ' + e.getMessage());
		}
	}

	@isTest
	private static void testConstructorWithParameter() {
		handler = new GTriggerHandlerTest.TestHandler('TestHandler');
		// override its internal trigger detection
		handler.isTriggerExecuting = true;
		beforeInsertMode();
		handler.run();
		assertTestHandlerName();
		Assert.areEqual('beforeInsert', lastMethodCalled, 'last method should be beforeInsert');
	}

	@isTest
	private static void testConstructorWithParametersAndBypass() {
		handler = new GTriggerHandlerTest.TestHandler('TestHandler');
		// override its internal trigger detection
		handler.isTriggerExecuting = true;
		beforeUpdateMode();
		GTriggerHandler.bypass('TestHandler');
		handler.run();
		Assert.isNull(lastMethodCalled, 'last method should be null when bypassed');
		Assert.isTrue(GTriggerHandler.isBypassed('TestHandler'), 'test handler should be bypassed');
		Assert.isTrue(!GTriggerHandler.bypassList().isEmpty(), 'Should have bypassed sample handler');
		Assert.isTrue(GTriggerHandler.bypassSet().contains('TestHandler'), 'The set of bypassed handlers should contain the test handler');
	}

	/**
	 * @description test bypass api
	 */
	@SuppressWarnings('PMD.NcssMethodCount')
	@isTest
	private static void testBypassAPI() {
		afterUpdateMode();

		// test a bypass by string and run handler
		GTriggerHandler.bypass('TestHandler');
		handler.run();
		Assert.isNull(lastMethodCalled, 'last method should be null when bypassed');
		Assert.isTrue(GTriggerHandler.isBypassed('TestHandler'), 'test handler should be bypassed');
		Assert.isTrue(!GTriggerHandler.bypassList().isEmpty(), 'Should have no bypassed handlers');
		resetTest();

		// clear that bypass and run handler
		GTriggerHandler.clearBypass('TestHandler');
		handler.run();
		Assert.areEqual('afterUpdate', lastMethodCalled, 'last method called should be afterUpdate');
		Assert.isFalse(GTriggerHandler.isBypassed('TestHandler'), 'test handler should not be bypassed');
		resetTest();

		// test a re-bypass by list and run handler
		GTriggerHandler.bypass(new List<String>{ 'TestHandler' });
		handler.run();
		Assert.isNull(lastMethodCalled, 'last method should be null when bypassed');
		Assert.isTrue(GTriggerHandler.isBypassed('TestHandler'), 'test handler should be bypassed');
		resetTest();

		// clear that bypass and run handler
		GTriggerHandler.clearBypass(new List<String>{ 'TestHandler' });
		handler.run();
		Assert.areEqual('afterUpdate', lastMethodCalled, 'last method called should be afterUpdate');
		Assert.isFalse(GTriggerHandler.isBypassed('TestHandler'), 'test handler should not be bypassed');
		resetTest();

		// test a bypass and run handler
		GTriggerHandler.bypass('TestHandler');
		handler.run();
		Assert.isNull(lastMethodCalled, 'last method should be null when bypassed');
		Assert.isTrue(GTriggerHandler.isBypassed('TestHandler'), 'test handler should be bypassed');
		resetTest();

		// clear all bypasses and run handler
		GTriggerHandler.clearAllBypasses();
		handler.run();
		Assert.areEqual('afterUpdate', lastMethodCalled, 'last method called should be afterUpdate');
		Assert.isFalse(GTriggerHandler.isBypassed('TestHandler'), 'test handler should not be bypassed');
		resetTest();

		// bypass everything
		GTriggerHandler.bypassAll();
		handler.run();
		Assert.isTrue(GTriggerHandler.bypassSet().contains(GTriggerHandler.BYPASS_ALL_ALIAS), 'When global bypass is true, put an item in the bypassed set');
		Assert.isTrue(GTriggerHandler.bypassedHandlers.isEmpty(), 'on bypass all, just set global variable to true and leave list empty');
		Assert.isTrue(GTriggerHandler.globalBypass, 'bypassing all should set global bypass to true');
		resetTest();

		GTriggerHandler.bypassAll();
		handler.run();
		Assert.isTrue(GTriggerHandler.isBypassed('TestHandler'), 'test handler should be bypassed');
		Assert.isTrue(GTriggerHandler.bypassList().contains(GTriggerHandler.BYPASS_ALL_ALIAS), 'When global bypass is true, put an item in the bypassed list');
		GTriggerHandler.clearAllBypasses();
		Assert.isTrue(GTriggerHandler.bypassList().isEmpty(), 'all bypassed handlers should be cleared');

		GTriggerHandler.setBypass('TestHandler', true);
		handler.run();
		Assert.isTrue(GTriggerHandler.isBypassed('TestHandler'), 'test handler should be bypassed');
		GTriggerHandler.bypassAll();
		GTriggerHandler.setBypass('TestHandler', false);
		Assert.isTrue(!GTriggerHandler.globalBypass, 'When one handler is set to run, global bypass should clear as well');
		Assert.isTrue(GTriggerHandler.bypassList().isEmpty(), 'Should have cleared all bypasses');
		GTriggerHandler.bypassAll();
		GTriggerHandler.setBypass('TestHandler', true);
		Assert.isTrue(GTriggerHandler.bypassList().contains(GTriggerHandler.BYPASS_ALL_ALIAS), 'Global bypass should be enabled');
		Assert.isTrue(GTriggerHandler.bypassList().contains('TestHandler'), 'Bypass list should still contain test handler');
		resetTest();

		GTriggerHandler.clearAllBypasses();
		GTriggerHandler.bypass('TestHandler');
		GTriggerHandler.setBypass('TestHandler', false);
		Assert.isTrue(GTriggerHandler.bypassList().isEmpty(), 'Should have cleared bypass list');
	}

	/**
	 * @description Test bypass by Type
	 */
	@IsTest
	static void testBypassByType() {
		afterUpdateMode();

		// test a bypass by string and run handler
		GTriggerHandler.bypass(TestHandler.class);
		Assert.isTrue(GTriggerHandler.isBypassed('GTriggerHandlerTest.TestHandler'), 'test handler should be bypassed');
		Assert.isTrue(GTriggerHandler.isBypassed(Testhandler.class), 'test handler class should be bypassed');
		handler.run();
		//Assert.isNull(lastMethodCalled, 'last method should be null when bypassed');
		resetTest();

		// clear that bypass and run handler
		GTriggerHandler.clearBypass(TestHandler.class);
		handler.run();
		Assert.areEqual('afterUpdate', lastMethodCalled, 'last method called should be afterUpdate');
		Assert.isFalse(GTriggerHandler.isBypassed('GTriggerHandlerTest.TestHandler'), 'test handler should not be bypassed');
		resetTest();
	}

	/**
	 * @description Test and show/hide limits and debug
	 */
	@isTest
	private static void testBeforeInsertWithLimits() {
		beforeInsertMode();
		GTriggerHandler.showLimits(false);
		GTriggerHandler.showLimits();
		GTriggerHandler.showDebug(null);
		GTriggerHandler.showDebug(true);
		GTriggerHandler.showDebug(false);
		handler.run();
		Assert.isFalse(GTriggerHandler.showDebug, 'We should not be showing debug'); //NOPMD
		GTriggerHandler.showDebug();
		handler.run();
		Assert.isTrue(GTriggerHandler.showLimits, 'We should be showing limits'); //NOPMD
		GTriggerHandler.getLoopCount('TestHandler');
		Assert.areEqual('beforeInsert', lastMethodCalled, 'last method should be beforeInsert');
	}

	/**
	 * @description Test and show/hide limits and debug using chaining
	 */
	@isTest
	private static void testBeforeInsertWithLimitsChaining() {
		beforeInsertMode();
		handler.limits().debug().run();
		Assert.isTrue(GTriggerHandler.showLimits, 'We should be showing limits'); //NOPMD
		Assert.isTrue(GTriggerHandler.showDebug, 'We should be showing debugs'); //NOPMD
		Assert.areEqual('beforeInsert', lastMethodCalled, 'last method should be beforeInsert');

		handler.limits(null).debug(null).run();
		Assert.isFalse(GTriggerHandler.showLimits, 'We should not be showing limits'); //NOPMD
		Assert.isFalse(GTriggerHandler.showDebug, 'We should not be showing debugs'); //NOPMD

		handler.limits(false).debug(false).run();
		Assert.isFalse(GTriggerHandler.showLimits, 'We should not be showing limits'); //NOPMD
		Assert.isFalse(GTriggerHandler.showDebug, 'We should not be showing debugs'); //NOPMD
	}

	/**
	 * @description instance method tests
	 */
	@isTest
	private static void testLoopCount() {
		beforeInsertMode();

		// set the max loops to 2
		// run the handler twice
		handler.setMaxLoopCount(2).run();
		handler.run();

		Assert.areEqual(2, GTriggerHandler.getLoopCount('TestHandler'), 'We should have run the handler only twice.');

		assertTestHandlerName();

		// clear the tests
		resetTest();
		GTriggerHandler.showDebug();

		handler.run();
		Assert.isTrue(GTriggerHandler.loopCountMap.get('TestHandler').getCount() > GTriggerHandler.loopCountMap.get('TestHandler').getMax(), 'We should have exceeded the max count');

		// clear the tests
		resetTest();

		// now clear the loop count
		handler.clearMaxLoopCount();

		handler.run();
		Assert.areEqual('beforeInsert', lastMethodCalled, 'last method should be beforeInsert');
	}

	@isTest
	private static void testLoopCountClass() {
		GTriggerHandler.LoopCount lc = new GTriggerHandler.LoopCount();
		Assert.areEqual(5, lc.getMax(), 'max should be five on init');
		Assert.areEqual(0, lc.getCount(), 'count should be zero on init');

		lc.increment();
		Assert.areEqual(1, lc.getCount(), 'count should be 1');
		Assert.isFalse(lc.exceeded(), 'should not be exceeded with count of 1');

		lc.increment();
		lc.increment();
		lc.increment();
		lc.increment();
		Assert.areEqual(5, lc.getCount(), 'count should be 5');
		Assert.isFalse(lc.exceeded(), 'should not be exceeded with count of 5');

		lc.increment();
		Assert.areEqual(6, lc.getCount(), 'count should be 6');
		Assert.isTrue(lc.exceeded(), 'should not be exceeded with count of 6');
	}

	/**
	 * @description Ensure that the current handler name is as expected
	 */
	private static void assertTestHandlerName() {
		Assert.areEqual('TestHandler', handler.getHandlerName(), 'handler name should match class name');
	}

	/**
	 * @description test virtual methods
	 */
	@isTest
	private static void testVirtualMethods() {
		GTriggerHandler h = new GTriggerHandler();
		h.beforeInsert();
		h.beforeUpdate();
		h.beforeDelete();
		h.afterInsert();
		h.afterUpdate();
		h.afterDelete();
		h.afterUndelete();
		Assert.isTrue(true, 'Method is for code coverage only - debug to avoid PMD error');
	}

	/**
	 * @description call from outside trigger
	 */
	@isTest
	private static void testOutsideTrigger() {
		GTriggerHandler th = new GTriggerHandler();
		Assert.isFalse(th.isTriggerExecuting, 'Should be outside trigger context');
		th.setTriggerContext(null, true);
		Assert.isFalse(th.isTriggerExecuting, 'Should be outside trigger context');
	}

	// testing utilities

	private static void resetTest() {
		lastMethodCalled = null;
	}

	// modes for testing

	private static void beforeInsertMode() {
		handler.setTriggerContext(System.TriggerOperation.BEFORE_INSERT, true);
	}

	private static void beforeUpdateMode() {
		handler.setTriggerContext(System.TriggerOperation.BEFORE_UPDATE, true);
	}

	private static void beforeDeleteMode() {
		handler.setTriggerContext(System.TriggerOperation.BEFORE_DELETE, true);
	}

	private static void afterInsertMode() {
		handler.setTriggerContext(System.TriggerOperation.AFTER_INSERT, true);
	}

	private static void afterUpdateMode() {
		handler.setTriggerContext(System.TriggerOperation.AFTER_UPDATE, true);
	}

	private static void afterDeleteMode() {
		handler.setTriggerContext(System.TriggerOperation.AFTER_DELETE, true);
	}

	private static void afterUndeleteMode() {
		handler.setTriggerContext(System.TriggerOperation.AFTER_UNDELETE, true);
	}

	/**
	 * @description test implementation of the TriggerHandler
	 */
	private class TestHandler extends GTriggerHandler {
		/**
		 * @description Invoke constructor
		 */
		public TestHandler() {
			super('TestHandler');
		}

		@SuppressWarnings('PMD.EmptyStatementBlock')
		/**
		 * @description       Override the trigger handler constructor that takes the handler name as a parameter
		 *
		 * @param handlerName The handler name to instantiate
		 */
		public TestHandler(String handlerName) {
		}

		public override void beforeInsert() {
			GTriggerHandlerTest.lastMethodCalled = 'beforeInsert';
		}

		public override void beforeUpdate() {
			GTriggerHandlerTest.lastMethodCalled = 'beforeUpdate';
		}

		public override void beforeDelete() {
			GTriggerHandlerTest.lastMethodCalled = 'beforeDelete';
		}

		public override void afterInsert() {
			GTriggerHandlerTest.lastMethodCalled = 'afterInsert';
		}

		public override void afterUpdate() {
			GTriggerHandlerTest.lastMethodCalled = 'afterUpdate';
		}

		public override void afterDelete() {
			GTriggerHandlerTest.lastMethodCalled = 'afterDelete';
		}

		public override void afterUndelete() {
			GTriggerHandlerTest.lastMethodCalled = 'afterUndelete';
		}
	}
}