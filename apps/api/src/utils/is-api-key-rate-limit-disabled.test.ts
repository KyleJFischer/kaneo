import { afterEach, describe, expect, it, vi } from "vite-plus/test";
import { isApiKeyRateLimitDisabled } from "./is-api-key-rate-limit-disabled";

describe("isApiKeyRateLimitDisabled", () => {
  afterEach(() => {
    vi.unstubAllEnvs();
  });

  it("is false when the variable is unset", () => {
    vi.stubEnv("DISABLE_API_KEY_RATE_LIMIT", undefined);
    expect(isApiKeyRateLimitDisabled()).toBe(false);
  });

  it("is true only for the exact string true", () => {
    vi.stubEnv("DISABLE_API_KEY_RATE_LIMIT", "true");
    expect(isApiKeyRateLimitDisabled()).toBe(true);
    vi.stubEnv("DISABLE_API_KEY_RATE_LIMIT", "1");
    expect(isApiKeyRateLimitDisabled()).toBe(false);
  });
});
