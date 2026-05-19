<?php
declare(strict_types=1);

/**
 * Shared layout for SEO / guide pages on jobsiterecords.com.
 *
 * @param array{
 *   title: string,
 *   description: string,
 *   canonical_path: string,
 *   body: string,
 *   og_title?: string,
 *   json_ld?: string|null,
 * } $opts
 */
function render_seo_page(array $opts): void
{
    $title = $opts['title'];
    $description = $opts['description'];
    $canonicalPath = $opts['canonical_path'];
    if ($canonicalPath === '' || $canonicalPath[0] !== '/') {
        throw new InvalidArgumentException('canonical_path must start with /');
    }
    $body = $opts['body'];
    $ogTitle = $opts['og_title'] ?? $title;
    $jsonLd = $opts['json_ld'] ?? null;

    $origin = site_public_origin();
    $canonicalUrl = $origin . $canonicalPath;

    header('Content-Type: text/html; charset=utf-8');

    echo '<!doctype html>' . "\n";
    echo '<html lang="en">' . "\n";
    echo '<head>' . "\n";
    echo '    <meta charset="utf-8">' . "\n";
    echo '    <title>' . h($title) . ' | Job Site Records</title>' . "\n";
    echo '    <meta name="viewport" content="width=device-width, initial-scale=1">' . "\n";
    echo '    <meta name="description" content="' . h($description) . '">' . "\n";
    echo '    <meta name="robots" content="index,follow">' . "\n";
    echo '    <link rel="canonical" href="' . h($canonicalUrl) . '">' . "\n";
    echo '    <meta property="og:title" content="' . h($ogTitle) . '">' . "\n";
    echo '    <meta property="og:description" content="' . h($description) . '">' . "\n";
    echo '    <meta property="og:type" content="article">' . "\n";
    echo '    <meta property="og:url" content="' . h($canonicalUrl) . '">' . "\n";
    echo '    <link rel="preconnect" href="https://fonts.googleapis.com">' . "\n";
    echo '    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>' . "\n";
    echo '    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800;900&display=swap" rel="stylesheet">' . "\n";
    if ($jsonLd !== null && $jsonLd !== '') {
        echo '    <script type="application/ld+json">' . "\n" . $jsonLd . "\n    </script>\n";
    }
    echo seo_layout_css();
    echo '    <!-- Cloudflare Web Analytics -->' . "\n";
    echo '    <script defer src="https://static.cloudflareinsights.com/beacon.min.js" data-cf-beacon=\'{"token": "af94f271002d48fba094746dc6b412f6"}\'></script>' . "\n";
    echo '    <!-- End Cloudflare Web Analytics -->' . "\n";
    echo '</head>' . "\n";
    echo '<body>' . "\n";
    echo seo_layout_top($canonicalPath);
    echo '<main class="article-shell">' . "\n";
    echo '    <div class="wrap article-wrap">' . "\n";
    echo $body;
    echo '    </div>' . "\n";
    echo '</main>' . "\n";
    echo seo_layout_footer();
    echo '</body>' . "\n";
    echo '</html>' . "\n";
}

function h(string $s): string
{
    return htmlspecialchars($s, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

function site_public_origin(): string
{
    $fromEnv = getenv('JOBSITERECORDS_PUBLIC_ORIGIN');
    if (is_string($fromEnv) && preg_match('#^https://[^\s]+$#', $fromEnv) === 1) {
        return rtrim($fromEnv, '/');
    }
    return 'https://jobsiterecords.com';
}

/** @return non-empty-string */
function guides_base_path(): string
{
    // Guides and resource hub live under /guides/ when docroot is landing/.
    return '/guides/';
}

/** @return list<non-empty-string> */
function resource_section_paths(): array
{
    return ['/use-cases/', '/answers/', '/trades/', '/examples/'];
}

function seo_layout_top(string $currentPath): string
{
    $home = '/';
    $resources = guides_base_path();
    $waitlist = '/#waitlist';

    $nav = static function (string $label, string $href, string $path): string {
        $isCurrent = $href === $path || ($href !== '/' && str_starts_with($path, rtrim($href, '/')));
        $cls = $isCurrent ? ' class="is-current"' : '';
        return '<a href="' . h($href) . '"' . $cls . '>' . $label . '</a>';
    };

    $resourcesCurrent = $currentPath === $resources
        || str_starts_with($currentPath, '/use-cases/')
        || str_starts_with($currentPath, '/answers/')
        || str_starts_with($currentPath, '/trades/')
        || str_starts_with($currentPath, '/examples/')
        || str_starts_with($currentPath, '/guides/');
    $resourcesCls = $resourcesCurrent ? ' class="is-current"' : '';

    ob_start();
    ?>
<div class="top">
    <div class="wrap top-inner">
        <a class="logo" href="<?= h($home) ?>">
            <span class="logo-mark" aria-hidden="true">
                <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
                    <rect x="6" y="3" width="12" height="3" rx="1"></rect>
                    <path d="M5 6h14a1 1 0 0 1 1 1v13a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1z"></path>
                    <path d="M9 12h6M9 16h4"></path>
                </svg>
            </span>
            <span class="logo-text">
                <strong>Job Site Records</strong>
                <span>Local field notes for contractors</span>
            </span>
        </a>
        <nav class="top-nav" aria-label="Site">
            <?= $nav('Home', $home, $currentPath) ?>
            <a href="<?= h($resources) ?>"<?= $resourcesCls ?>>Resources</a>
            <a href="<?= h($home) ?>#features">Features</a>
            <a href="<?= h($home) ?>#faq">FAQ</a>
        </nav>
        <div class="top-right">
            <span class="top-domain">jobsiterecords.com</span>
            <a class="btn btn-primary" href="<?= h($waitlist) ?>">Request early access</a>
        </div>
    </div>
</div>
    <?php
    return (string)ob_get_clean();
}

function seo_layout_footer(): string
{
    return <<<'HTML'
<footer class="site-footer">
    <div class="wrap">
        <strong>Job Site Records</strong> · jobsiterecords.com<br>
        <a href="mailto:contact@jobsiterecords.com">contact@jobsiterecords.com</a><br>
        Local-first field notes for contractors. Made for the field.
    </div>
</footer>
HTML;
}

function seo_layout_css(): string
{
    return <<<'HTML'
    <style>
        :root {
            --cream:        #f8f3e6;
            --cream-card:   #ffffff;
            --ink:          #14110d;
            --ink-soft:     #3d3830;
            --ink-mute:     #807a6e;
            --line:         #e6dcc4;
            --yellow:       #f5c518;
            --yellow-hover: #e0b200;
            --radius:       18px;
            --radius-sm:    12px;
            --shadow:       0 6px 24px rgba(20, 17, 13, 0.08);
        }
        *, *::before, *::after { box-sizing: border-box; }
        html { scroll-behavior: smooth; }
        body {
            margin: 0;
            font-family: "Inter", system-ui, -apple-system, BlinkMacSystemFont, sans-serif;
            background: var(--cream);
            color: var(--ink);
            line-height: 1.6;
            font-size: 17px;
            -webkit-font-smoothing: antialiased;
            text-rendering: optimizeLegibility;
        }
        a { color: var(--ink); text-decoration: none; font-weight: 500; }
        a:hover { color: var(--yellow-hover); }
        .wrap { max-width: 1180px; margin: 0 auto; padding: 0 24px; }
        .top {
            position: sticky;
            top: 0;
            z-index: 50;
            background: rgba(248, 243, 230, 0.92);
            backdrop-filter: blur(10px);
            border-bottom: 1px solid rgba(20, 17, 13, 0.06);
        }
        .top-inner {
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 18px;
            padding: 16px 0;
            flex-wrap: wrap;
        }
        .logo { display: flex; align-items: center; gap: 12px; }
        .logo-mark {
            width: 44px; height: 44px;
            border-radius: 11px;
            background: var(--yellow);
            display: grid;
            place-items: center;
            color: var(--ink);
            flex-shrink: 0;
        }
        .logo-text strong {
            display: block;
            font-size: 1.05rem;
            font-weight: 800;
            line-height: 1.1;
            letter-spacing: -0.01em;
        }
        .logo-text span {
            font-size: 0.78rem;
            color: var(--ink-mute);
            font-weight: 500;
        }
        .top-nav { display: flex; align-items: center; gap: 22px; flex-wrap: wrap; }
        .top-nav a {
            font-size: 0.92rem;
            color: var(--ink-soft);
            font-weight: 600;
        }
        .top-nav a:hover { color: var(--yellow-hover); }
        .top-nav a.is-current { color: var(--ink); text-decoration: underline; text-underline-offset: 4px; }
        .top-right { display: flex; align-items: center; gap: 18px; flex-wrap: wrap; }
        .top-domain { font-size: 0.9rem; color: var(--ink-mute); font-weight: 500; }
        .btn {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            gap: 10px;
            padding: 12px 22px;
            border-radius: 999px;
            font-weight: 700;
            font-size: 0.95rem;
            font-family: inherit;
            border: none;
            cursor: pointer;
            text-decoration: none;
            line-height: 1;
        }
        .btn-primary { background: var(--yellow); color: var(--ink); }
        .btn-primary:hover { background: var(--yellow-hover); color: var(--ink); }
        .article-shell { padding: 36px 0 64px; }
        .article-wrap { max-width: 720px; }
        article.guide {
            background: var(--cream-card);
            border: 1px solid var(--line);
            border-radius: var(--radius);
            padding: 36px 32px 40px;
            box-shadow: var(--shadow);
        }
        @media (max-width: 600px) {
            article.guide { padding: 26px 20px 32px; }
        }
        article.guide .eyebrow {
            display: block;
            font-size: 0.78rem;
            font-weight: 800;
            letter-spacing: 0.12em;
            text-transform: uppercase;
            color: var(--ink-mute);
            margin-bottom: 10px;
        }
        article.guide h1 {
            font-size: clamp(1.75rem, 4.5vw, 2.35rem);
            font-weight: 900;
            letter-spacing: -0.03em;
            line-height: 1.12;
            margin: 0 0 16px;
        }
        article.guide .lead {
            font-size: 1.12rem;
            color: var(--ink-soft);
            margin: 0 0 28px;
            line-height: 1.55;
        }
        article.guide h2 {
            font-size: 1.25rem;
            font-weight: 800;
            letter-spacing: -0.02em;
            margin: 32px 0 12px;
        }
        article.guide p { margin: 0 0 14px; color: var(--ink-soft); }
        article.guide ul, article.guide ol { margin: 0 0 16px; padding-left: 1.35em; color: var(--ink-soft); }
        article.guide li { margin-bottom: 8px; }
        article.guide code {
            font-size: 0.88em;
            background: rgba(245, 197, 24, 0.22);
            padding: 0.1em 0.35em;
            border-radius: 4px;
        }
        article.guide table {
            width: 100%;
            border-collapse: collapse;
            margin: 18px 0;
            font-size: 0.94rem;
        }
        article.guide th, article.guide td {
            border: 1px solid var(--line);
            padding: 10px 12px;
            text-align: left;
            vertical-align: top;
        }
        article.guide th { background: rgba(245, 197, 24, 0.14); font-weight: 700; color: var(--ink); }
        article.guide blockquote.sample {
            margin: 18px 0;
            padding: 16px 18px;
            border-left: 4px solid var(--yellow);
            background: rgba(245, 197, 24, 0.08);
            color: var(--ink-soft);
            font-size: 0.96rem;
        }
        article.guide blockquote.sample p:last-child { margin-bottom: 0; }
        .guide-cta {
            margin-top: 32px;
            padding: 22px 22px 24px;
            border-radius: var(--radius-sm);
            background: linear-gradient(135deg, rgba(245, 197, 24, 0.2), rgba(245, 197, 24, 0.06));
            border: 1px solid var(--line);
        }
        .guide-cta strong { display: block; font-size: 1.05rem; margin-bottom: 8px; color: var(--ink); }
        .guide-cta p { margin: 0 0 14px; font-size: 0.95rem; }
        .related { margin-top: 36px; padding-top: 24px; border-top: 1px solid var(--line); }
        .related h2 { font-size: 1.05rem; margin-top: 0; }
        .related ul { list-style: none; padding: 0; margin: 0; }
        .related li { margin-bottom: 10px; }
        .muted { font-size: 0.88rem; color: var(--ink-mute); }
        footer.site-footer {
            padding: 44px 0;
            text-align: center;
            font-size: 0.88rem;
            color: var(--ink-mute);
            border-top: 1px solid var(--line);
        }
        footer.site-footer strong { color: var(--ink); }
        footer.site-footer a {
            color: var(--ink-soft);
            text-decoration: none;
        }
        footer.site-footer a:hover { text-decoration: underline; }
        .guides-list-page h1 { font-size: clamp(1.8rem, 4vw, 2.5rem); font-weight: 900; letter-spacing: -0.03em; margin: 0 0 12px; }
        .guides-list-page .lead { color: var(--ink-soft); max-width: 40em; margin: 0 0 28px; }
        .guides-grid { display: grid; gap: 14px; }
        .guides-grid a {
            display: block;
            padding: 18px 20px;
            background: var(--cream-card);
            border: 1px solid var(--line);
            border-radius: var(--radius-sm);
            font-weight: 700;
            box-shadow: var(--shadow);
        }
        .guides-grid a:hover { border-color: var(--yellow-hover); }
        .guides-grid a span { display: block; font-weight: 500; font-size: 0.88rem; color: var(--ink-mute); margin-top: 6px; }
        @media (max-width: 720px) {
            .top-nav { display: none; }
            .top-domain { display: none; }
        }
    </style>
HTML;
}
