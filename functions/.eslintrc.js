module.exports = {
  root: true,
  env: {es6: true, node: true},
  extends: [
    "eslint:recommended",
    "plugin:@typescript-eslint/recommended",
    "google",
  ],
  parser: "@typescript-eslint/parser",
  parserOptions: {ecmaVersion: 2020, sourceType: "module"},
  ignorePatterns: ["/lib/**/*", "/node_modules/**/*"],
  plugins: ["@typescript-eslint"],
  rules: {
    "quotes": ["error", "double"],
    "max-len": ["warn", {code: 100}],
    "require-jsdoc": "off",
    "valid-jsdoc": "off",
    "object-curly-spacing": ["error", "never"],
    "@typescript-eslint/no-explicit-any": "warn",
  },
};
