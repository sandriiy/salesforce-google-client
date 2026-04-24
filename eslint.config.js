const lwcRecommended = require("@salesforce/eslint-config-lwc/recommended");
const globals = require("globals");

module.exports = [
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
