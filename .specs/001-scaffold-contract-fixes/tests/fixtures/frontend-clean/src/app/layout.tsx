const siteUrl = process.env.SITE_URL ?? "http://localhost:33000";

export const metadata = {
  title: "Fixture",
  metadataBase: new URL(siteUrl),
  alternates: { canonical: siteUrl },
};
