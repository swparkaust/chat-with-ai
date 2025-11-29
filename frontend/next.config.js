/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  devIndicators: false,
  async rewrites() {
    return [
      {
        source: '/api/:path*',
        destination: process.env.NEXT_PUBLIC_API_URL + '/api/:path*',
      },
      {
        source: '/cable',
        destination: process.env.NEXT_PUBLIC_API_URL + '/cable',
      },
    ];
  },
};

module.exports = nextConfig;
