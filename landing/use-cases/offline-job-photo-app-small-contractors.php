<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Use case</span>
    <h1>Offline job photos for two-truck outfits</h1>
    <p class="lead">If your “IT department” is whoever remembers the Wi-Fi password at the supply house, you do not need enterprise onboarding. You need something that still works in a basement stairwell, a tilt-up with weird RF, or that one county where LTE pretends to exist.</p>

    <h2>The bar is low—and that is the point</h2>
    <p>Open app, pick job, shoot, tag, done. No “waiting for upload” spinner before you can take the next picture. That single detail is what keeps crews using a tool past week two.</p>

    <h2>Export is your filing cabinet</h2>
    <p>Small shops often live in email and text. A zip with an index beats a thread where half the images are compressed into mush. Send it to yourself too—your inbox is not a backup, but it is better than nothing until you pick a drive policy.</p>

    <div class="guide-cta">
        <strong>Job Site Records</strong>
        <p>Phase 1 is local-only: capture offline, share when you choose.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related">
        <h2>Related</h2>
        <ul>
            <li><a href="/use-cases/">All use cases</a></li>
            <li><a href="/answers/account-required-vs-accountless-field-apps.php">Account vs no account</a></li>
            <li><a href="/guides/offline-job-site-documentation.php">Offline documentation guide</a></li>
        </ul>
    </nav>
</article>
HTML;

render_seo_page([
    'title' => 'Offline job photos for small contractors',
    'description' => 'Why small contractors need offline-first job photos: no upload gate, zip export, works in bad signal.',
    'canonical_path' => '/use-cases/offline-job-photo-app-small-contractors.php',
    'body' => $body,
]);
