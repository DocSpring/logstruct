// Site configuration

/**
 * Determines if the site should show the "coming soon" page
 * - In production: always true
 * - In development: controlled by NEXT_PUBLIC_SHOW_COMING_SOON env variable
 */
// export const isComingSoon =
//   // Always show coming soon page in production
//   process.env.NODE_ENV === 'production' ||
//   // In development, use the environment variable to toggle
//   process.env.NEXT_PUBLIC_SHOW_COMING_SOON === 'true';
export const isComingSoon = false;
