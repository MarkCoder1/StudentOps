/** @type {import('next').NextConfig} */
const nextConfig = {
  // Ensure server can use better-sqlite3 native (Next 15: serverExternalPackages)
  serverExternalPackages: ["better-sqlite3"],
  experimental: {
    serverComponentsExternalPackages: ["better-sqlite3"],
  },
};
export default nextConfig;
