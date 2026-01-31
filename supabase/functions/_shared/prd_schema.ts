export type GeneratePrdRequest = {
  title: string;
  description: string;
};

export type GeneratePrdResponse = {
  /**
   * The path committed in the repo, e.g. `docs/PRD_feature_slug.md`
   */
  path: string;
  /**
   * Link to view the PRD on GitHub.
   */
  url: string;
  /**
   * Commit SHA (or content SHA) from GitHub response.
   */
  sha: string;
};

