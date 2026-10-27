const lwcConfig = require("@salesforce/eslint-config-lwc");

const lwcFiles = ["force-app/**/lwc/**/*.js", "demo-app/**/lwc/**/*.js"];

module.exports = [
  { ignores: ["node_modules/**", "coverage/**", ".verify/**"] },
  ...lwcConfig.configs.recommended.map((config) => ({
    ...config,
    files: lwcFiles
  })),
  {
    files: ["force-app/**/lwc/**/__tests__/**/*.js", "demo-app/**/lwc/**/__tests__/**/*.js"],
    languageOptions: {
      globals: {
        jest: "readonly",
        describe: "readonly",
        it: "readonly",
        expect: "readonly",
        beforeEach: "readonly",
        afterEach: "readonly"
      }
    }
  }
];
