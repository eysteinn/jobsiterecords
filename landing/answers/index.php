<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$origin = site_public_origin();
$listLd = json_encode([
    '@context' => 'https://schema.org',
    '@type' => 'CollectionPage',
    'name' => 'Answers & comparisons — job site documentation',
    'url' => $origin . '/answers/',
    'isPartOf' => ['@type' => 'WebSite', 'name' => 'Job Site Records', 'url' => $origin . '/'],
], JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);

$body = <<<'HTML'
<div class="guides-list-page">
    <span class="eyebrow" style="display:block;font-size:0.78rem;font-weight:800;letter-spacing:0.12em;text-transform:uppercase;color:var(--ink-mute);margin-bottom:10px;">Answers</span>
    <h1>Pick your fight</h1>
    <p class="lead">These are opinionated comparisons—grounded in small-crew reality, not feature matrices from Mars. We sell Job Site Records, so we are not pretending we have no horse in the race. We still try to tell you when a heavier tool is actually the right one.</p>

    <div class="guides-grid" role="list">
        <a href="job-site-records-vs-field-photo-apps.php" role="listitem"><span>Job Site Records vs team photo apps</span><span>When cloud dashboards earn their keep—and when they slow the guy on the lift.</span></a>
        <a href="zip-export-vs-cloud-only-daily-logs.php" role="listitem"><span>Zip export vs cloud-only logs</span><span>Ownership, awkward email attachments, and Friday-night peace.</span></a>
        <a href="field-notes-daily-log-app-vs-group-chat.php" role="listitem"><span>Daily log app vs group chat</span><span>Why threads love to eat proof.</span></a>
        <a href="voice-notes-vs-typed-field-reports.php" role="listitem"><span>Voice vs typed field reports</span><span>Gloves, ladders, and the lie of “I’ll type it later.”</span></a>
        <a href="lightweight-capture-vs-construction-pm-software.php" role="listitem"><span>Lightweight capture vs PM suites</span><span>Not every job needs a schedule Gantt to take a picture of a mud ring.</span></a>
        <a href="paper-daily-reports-vs-phone-job-photos.php" role="listitem"><span>Paper daily reports vs phone photos</span><span>Clipboards are honest. They also melt in rain.</span></a>
        <a href="free-local-documentation-vs-enterprise-platforms.php" role="listitem"><span>Free local docs vs enterprise platforms</span><span>Seat math, onboarding drag, and who really pays.</span></a>
        <a href="account-required-vs-accountless-field-apps.php" role="listitem"><span>Account required vs account-less apps</span><span>What “sign up” signals to crews on day one.</span></a>
        <a href="phone-photos-vs-dedicated-site-camera.php" role="listitem"><span>Phone vs dedicated site camera</span><span>When a rugged point-and-shoot still wins—and when it stays in the truck.</span></a>
        <a href="caption-and-tags-vs-exif-only-evidence.php" role="listitem"><span>Captions &amp; tags vs EXIF-only</span><span>Timestamps do not explain a valve orientation.</span></a>
    </div>

    <p class="muted" style="margin-top:28px"><a href="/guides/">All resources</a></p>
</div>
HTML;

render_seo_page([
    'title' => 'Answers & comparisons',
    'description' => 'Comparisons: zip vs cloud, chat vs log, voice vs typed, PM suites vs lightweight capture, phone vs camera, captions vs EXIF.',
    'canonical_path' => '/answers/',
    'body' => $body,
    'json_ld' => $listLd,
]);
