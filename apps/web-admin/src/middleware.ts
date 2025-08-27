import createMiddleware from 'next-intl/middleware';

export default createMiddleware({
  locales: ['tr', 'en'],
  defaultLocale: 'tr',

  // Hiç prefix yok
  localePrefix: 'never'
});

export const config = {
  matcher: [
    '/((?!api|_next|.*\\..*).*)'
  ]
};
