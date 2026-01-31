function getEnv(name: string, fallback = ""): string {
  try {
    return Deno.env.get(name) ?? fallback;
  } catch (_) {
    return fallback;
  }
}

function assertNonEmpty(name: string, value: string): string {
  const v = value.trim();
  if (!v) throw new Error(`${name}_missing`);
  return v;
}

function parseRepo(full: string): { owner: string; repo: string } {
  const trimmed = full.trim();
  const parts = trimmed.split("/");
  if (parts.length !== 2) throw new Error("github_repo_invalid");
  const owner = parts[0]!.trim();
  const repo = parts[1]!.trim();
  if (!owner || !repo) throw new Error("github_repo_invalid");
  return { owner, repo };
}

function base64EncodeUtf8(text: string): string {
  const bytes = new TextEncoder().encode(text);
  // Convert bytes -> binary string safely in chunks.
  let binary = "";
  const chunkSize = 0x8000;
  for (let i = 0; i < bytes.length; i += chunkSize) {
    const chunk = bytes.subarray(i, i + chunkSize);
    for (let j = 0; j < chunk.length; j++) {
      binary += String.fromCharCode(chunk[j]!);
    }
  }
  // btoa expects Latin1/binary string.
  return btoa(binary);
}

async function ghJson<T>(opts: {
  token: string;
  method: string;
  url: string;
  body?: unknown;
}): Promise<{ ok: true; value: T } | { ok: false; status: number; data: any }> {
  const res = await fetch(opts.url, {
    method: opts.method,
    headers: {
      "Accept": "application/vnd.github+json",
      "Authorization": `Bearer ${opts.token}`,
      "X-GitHub-Api-Version": "2022-11-28",
      ...(opts.body ? { "Content-Type": "application/json" } : {}),
    },
    body: opts.body ? JSON.stringify(opts.body) : undefined,
  });
  const data = await res.json().catch(() => null);
  if (!res.ok) return { ok: false, status: res.status, data };
  return { ok: true, value: data as T };
}

export type GitHubPutFileResult = {
  path: string;
  branch: string;
  htmlUrl: string;
  sha: string;
};

/**
 * Create or update a file in a GitHub repo using the Contents API.
 *
 * Notes:
 * - For "create", omit sha.
 * - For "update", you must supply the existing file's sha.
 */
export async function githubPutFile(opts: {
  token: string;
  repo: string; // owner/repo
  branch?: string;
  path: string;
  contentUtf8: string;
  message: string;
  sha?: string;
}): Promise<GitHubPutFileResult> {
  const token = assertNonEmpty("GITHUB_TOKEN", opts.token);
  const { owner, repo } = parseRepo(opts.repo);
  const branch = (opts.branch ?? getEnv("GITHUB_BRANCH", "main")).trim() || "main";
  const base = (getEnv("GITHUB_API_BASE", "https://api.github.com")).trim() ||
    "https://api.github.com";

  const url = `${base}/repos/${encodeURIComponent(owner)}/${encodeURIComponent(repo)}/contents/${opts.path
    .split("/")
    .map((p) => encodeURIComponent(p))
    .join("/")}`;

  const body: Record<string, unknown> = {
    message: opts.message,
    content: base64EncodeUtf8(opts.contentUtf8),
    branch,
  };
  if (opts.sha) body["sha"] = opts.sha;

  type PutResponse = {
    content?: { sha?: string; path?: string; html_url?: string };
    commit?: { sha?: string };
  };

  const put = await ghJson<PutResponse>({ token, method: "PUT", url, body });
  if (!put.ok) {
    throw new Error(`github_put_${put.status}`);
  }

  const outPath = put.value.content?.path ?? opts.path;
  const htmlUrl =
    put.value.content?.html_url ?? `https://github.com/${owner}/${repo}/blob/${branch}/${outPath}`;
  const sha = put.value.commit?.sha ?? put.value.content?.sha ?? "";

  if (!sha) throw new Error("github_put_no_sha");

  return { path: outPath, branch, htmlUrl, sha };
}

export async function githubGetFileSha(opts: {
  token: string;
  repo: string; // owner/repo
  branch?: string;
  path: string;
}): Promise<string | null> {
  const token = assertNonEmpty("GITHUB_TOKEN", opts.token);
  const { owner, repo } = parseRepo(opts.repo);
  const branch = (opts.branch ?? getEnv("GITHUB_BRANCH", "main")).trim() || "main";
  const base = (getEnv("GITHUB_API_BASE", "https://api.github.com")).trim() ||
    "https://api.github.com";

  const url = `${base}/repos/${encodeURIComponent(owner)}/${encodeURIComponent(repo)}/contents/${opts.path
    .split("/")
    .map((p) => encodeURIComponent(p))
    .join("/")}?ref=${encodeURIComponent(branch)}`;

  type GetResponse = { sha?: string };
  const get = await ghJson<GetResponse>({ token, method: "GET", url });
  if (!get.ok) {
    if (get.status === 404) return null;
    throw new Error(`github_get_${get.status}`);
  }
  const sha = get.value.sha;
  return typeof sha === "string" && sha.trim().length > 0 ? sha : null;
}

