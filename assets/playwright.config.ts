import { defineConfig, devices } from '@playwright/test'
import path from 'path'

/**
 * See https://playwright.dev/docs/test-configuration.
 */
export default defineConfig({
  testDir: './playwright-tests',

  /* Location where snapshots and screenshots are stored */
  snapshotPathTemplate: '{testDir}/snapshots/{testFileName}-{testName}-{arg}{ext}',
  updateSnapshots: 'all',


  /* Run tests in files in parallel */
  fullyParallel: true,
  /* Fail the build on CI if you accidentally left test.only in the source code. */
  forbidOnly: !!process.env.CI,
  /* Retry on CI only */
  retries: process.env.CI ? 2 : 0,
  /* Opt out of parallel tests on CI. */
  workers: process.env.CI ? 1 : undefined,
  /* Reporter to use. See https://playwright.dev/docs/test-reporters */
  reporter: process.env.CI ? 'github' : 'list',
  /* Shared settings for all the projects below. See https://playwright.dev/docs/api/class-testoptions. */
  use: {
    /* Base URL to use in actions like `await page.goto('/')`. */
    baseURL: 'http://localhost:8000',

    /* Collect trace when retrying the failed test. See https://playwright.dev/docs/trace-viewer */
    trace: 'on-first-retry',
    ...devices['Desktop Chrome']
  },

  /* Configure projects for major browsers */
  projects: [
    {
      name: 'setup',
      testMatch: /global\.setup\.ts/,
    },
    {
      name: 'chromium',
      dependencies: ['setup'],
      use: {
        storageState: 'playwright-tests/.auth/user.json',
        viewport: { width: 1280, height: 3000 },
      }
    },
  ],

  /* Run your local dev server before starting the tests */
  webServer: {
    command: 'mix phx.server',
    url: 'http://localhost:8000',
    cwd: path.resolve(__dirname, '..'),
    reuseExistingServer: !process.env.CI,
    stderr: 'ignore'
  },
});
