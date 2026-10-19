export function isApiKeyRateLimitDisabled(): boolean {
  return process.env.DISABLE_API_KEY_RATE_LIMIT === "true";
}
