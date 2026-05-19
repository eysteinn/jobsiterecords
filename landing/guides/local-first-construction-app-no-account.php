<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$canonicalPath = '/guides/local-first-construction-app-no-account.php';

$faqLd = json_encode([
    '@context' => 'https://schema.org',
    '@type' => 'FAQPage',
    'mainEntity' => [
        [
            '@type' => 'Question',
            'name' => 'What does local-first mean for a construction app?',
            'acceptedAnswer' => [
                '@type' => 'Answer',
                'text' => 'Local-first means capture, storage, and browsing work on the device without needing cloud upload or authentication to function. Sharing happens later through explicit export actions the user controls.',
            ],
        ],
        [
            '@type' => 'Question',
            'name' => 'Why ship a contractor app without mandatory accounts?',
            'acceptedAnswer' => [
                '@type' => 'Answer',
                'text' => 'Accounts add friction on first use and can imply data leaves the phone. For field evidence tools, removing signup speeds adoption and keeps the privacy story simple: your job media stays local until you share it.',
            ],
        ],
        [
            '@type' => 'Question',
            'name' => 'Can teams still collaborate without accounts?',
            'acceptedAnswer' => [
                '@type' => 'Answer',
                'text' => 'Not inside the same database. Phase 1 style apps focus on individual capture and zip export. Optional paid team sync with sign-in is a separate layer for orgs that choose it later.',
            ],
        ],
    ],
], JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Guides</span>
    <h1>Local-first construction app with no account</h1>
    <p class="lead"><strong>Local-first</strong> means the field workflow never waits on Wi-Fi, OAuth screens, or "sync pending." <strong>No account</strong> means you can document a walk-through minutes after install. It matters when crews bounce between sites.</p>

    <h2>Tradeoffs to understand</h2>
    <p>Without cloud sync, the phone is the source of truth until you export. Back up exports to company storage if policy requires it. That is a conscious action, not silent background upload.</p>

    <h2>When accounts return value</h2>
    <p>Teams that need multi-device continuity, dashboards, and shared workspaces benefit from sign-in. But it should remain optional for crews who only want capture and zip handoff.</p>

    <section aria-labelledby="faq-local">
        <h2 id="faq-local">Quick answers</h2>
        <h3>What does local-first mean for a construction app?</h3>
        <p>Local-first means capture, storage, and browsing work on the device without needing cloud upload or authentication to function. Sharing happens later through explicit export actions the user controls.</p>
        <h3>Why ship a contractor app without mandatory accounts?</h3>
        <p>Accounts add friction on first use and can imply data leaves the phone. For field evidence tools, removing signup speeds adoption and keeps the privacy story simple: your job media stays local until you share it.</p>
        <h3>Can teams still collaborate without accounts?</h3>
        <p>Not inside the same database. Phase 1 style apps focus on individual capture and zip export. Optional paid team sync with sign-in is a separate layer for orgs that choose it later.</p>
    </section>

    <div class="guide-cta">
        <strong>Capture first, cloud optional later</strong>
        <p>Job Site Records keeps Phase 1 local-only; team sync is on the roadmap for orgs that need it.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related guides">
        <h2>Related</h2>
        <ul>
            <li><a href="local-private-job-site-data.php">Local, private job site data</a></li>
            <li><a href="job-site-records-free-vs-pro-teams.php">Free app vs Pro teams (roadmap)</a></li>
            <li><a href="what-is-job-site-records.php">What is Job Site Records?</a></li>
        </ul>
    </nav>
</article>
HTML;

render_seo_page([
    'title' => 'Local-first construction app, no account',
    'description' => 'What local-first and account-less mean for contractor job documentation, tradeoffs, and when team sign-in makes sense.',
    'canonical_path' => $canonicalPath,
    'body' => $body,
    'json_ld' => $faqLd,
]);
