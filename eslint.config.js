// ESLint v9 flat config — migrated from force-app/main/default/lwc/.eslintrc.json
const lwcRecommended = require("@salesforce/eslint-config-lwc/recommended");
const globals = require("globals");

module.exports = [
  // Scope all LWC recommended rules to LWC/Aura JS files only
  ...lwcRecommended.map((config) => ({
    ...config,
    files: ["**/{aura,lwc}/**/*.js"]
  })),
  {
    files: ["**/{aura,lwc}/**/*.test.js"],
    rules: {
      "@lwc/lwc/no-unexpected-wire-adapter-usages": "off"
    },
    languageOptions: {
      globals: {
        ...globals.node
      }
    }
  }
];
