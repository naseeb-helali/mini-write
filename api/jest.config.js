module.exports = {
  testEnvironment: 'node',
  verbose: true,
  forceExit: true,
  clearMocks: true,
  resetModules: true,
  testTimeout: 10000,
  // سنضع كل ملفات التست في مجلد واحد لسهولة الإدارة
  testMatch: ["**/tests/**/*.test.js"], 
  // السطر الجديد:
  setupFiles: ["<rootDir>/tests/setup.js"],
  // لضمان توافق التقارير مع الـ Pipeline
  collectCoverage: true,
  coverageDirectory: "coverage",
  coverageReporters: ["json-summary", "text", "lcov"]
};