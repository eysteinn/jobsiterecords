<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$origin = site_public_origin();
$listLd = json_encode([
    '@context' => 'https://schema.org',
    '@type' => 'CollectionPage',
    'name' => 'Job Site Records — resources',
    'description' => 'Use cases, comparisons, trade notes, and examples for job-site photos, voice notes, and zip exports.',
    'url' => $origin . '/guides/',
    'isPartOf' => ['@type' => 'WebSite', 'name' => 'Job Site Records', 'url' => $origin . '/'],
], JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);

$body = <<<'HTML'
<div class="guides-list-page">
    <span class="eyebrow" style="display:block;font-size:0.78rem;font-weight:800;letter-spacing:0.12em;text-transform:uppercase;color:var(--ink-mute);margin-bottom:10px;">Resources</span>
    <h1>Field docs without the enterprise tax</h1>
    <p class="lead">Some crews want a 90-second answer. Others want a whole trade-specific habit. We split things that way on purpose—use-case pages when you are pitching a workflow to yourself, comparison pages when you are picking tools, trade pages when the sparky on your crew rolls eyes at “just take more photos,” and examples when you need something to steal outright.</p>

    <h2 style="font-size:1.15rem;font-weight:800;margin:28px 0 14px;letter-spacing:-0.02em;">Start here</h2>
    <div class="guides-grid" role="list">
        <a href="/use-cases/" role="listitem"><span>Use cases</span><span>Why people pick up the phone in the first place—TI work, punch lists, rough-in, closeout, that sort of thing.</span></a>
        <a href="/answers/" role="listitem"><span>Answers &amp; comparisons</span><span>Chat vs log, zip vs cloud, phone vs “real” camera—opinions backed by field constraints, not vendor bingo.</span></a>
        <a href="/trades/" role="listitem"><span>Trade notes</span><span>Electrical, plumbing, remodel, roof, concrete, paint—same app, different habits.</span></a>
        <a href="/examples/" role="listitem"><span>Templates &amp; examples</span><span>Emails, caption lists, tag sets, and scripts you can copy and ugly-edit until they sound like you.</span></a>
    </div>

    <h2 style="font-size:1.15rem;font-weight:800;margin:36px 0 14px;letter-spacing:-0.02em;">Short guides (older format, still useful)</h2>
    <p class="muted" style="margin-bottom:18px">These are tighter articles—mostly written before we split the library into buckets. Same tone, less packaging.</p>
    <div class="guides-grid" role="list">
        <a href="before-during-after-construction-photos.php" role="listitem"><span>Before, during, and after photos</span><span>Progress sets clients trust. And protects your work.</span></a>
        <a href="client-progress-updates-without-pm-software.php" role="listitem"><span>Client updates without PM software</span><span>Weekly rhythm, zip bundles, what owners need.</span></a>
        <a href="construction-defect-documentation-checklist.php" role="listitem"><span>Defect documentation checklist</span><span>Context, close-ups, measurements, tags, voice.</span></a>
        <a href="contractor-photo-evidence-for-change-orders.php" role="listitem"><span>Photo evidence for change orders</span><span>Shot list, tags, voice, and how to bundle proof.</span></a>
        <a href="daily-construction-job-log.php" role="listitem"><span>Daily construction job log</span><span>A simple timeline per job instead of scattered threads.</span></a>
        <a href="document-issues-and-change-orders.php" role="listitem"><span>Document issues and change orders</span><span>Dated evidence when scope or conditions shift.</span></a>
        <a href="export-job-site-zip-html-csv.php" role="listitem"><span>Export a job as zip (HTML + CSV)</span><span>What is inside the archive and who can open it.</span></a>
        <a href="field-documentation-trades-remodel.php" role="listitem"><span>Field documentation for trades</span><span>Remodel, plumbing, electrical, landscaping, and more.</span></a>
        <a href="job-site-records-free-vs-pro-teams.php" role="listitem"><span>Free app vs Pro teams (roadmap)</span><span>Local-first today; optional sync and dashboard later.</span></a>
        <a href="local-first-construction-app-no-account.php" role="listitem"><span>Local-first app, no account</span><span>What it means, tradeoffs, when sign-in helps.</span></a>
        <a href="local-private-job-site-data.php" role="listitem"><span>Local, private job site data</span><span>What “stays on your device” means in practice.</span></a>
        <a href="offline-construction-daily-log-app.php" role="listitem"><span>Offline construction daily log app</span><span>Why per-job timelines beat group chat threads.</span></a>
        <a href="offline-job-site-documentation.php" role="listitem"><span>Offline job site documentation</span><span>No signal, no problem: photos, voice, and notes on your phone.</span></a>
        <a href="organize-job-site-photos-trades-and-tags.php" role="listitem"><span>Organize job site photos with tags</span><span>Small tag palettes, trade labels, caption rules.</span></a>
        <a href="photo-captions-metadata-construction-documentation.php" role="listitem"><span>Captions and metadata for construction photos</span><span>EXIF vs human context, captions vs tags.</span></a>
        <a href="subcontractor-to-gc-documentation-handoff.php" role="listitem"><span>Subcontractor documentation for GCs</span><span>Rough-in, finish, and review-friendly packages.</span></a>
        <a href="tag-and-caption-site-photos.php" role="listitem"><span>Tag and caption site photos</span><span>Turn a camera roll into a readable story.</span></a>
        <a href="voice-memos-vs-notes-field-documentation.php" role="listitem"><span>Voice memos vs typed notes</span><span>When audio wins, when text wins, ideal clip length.</span></a>
        <a href="voice-notes-for-contractors.php" role="listitem"><span>Voice notes for contractors</span><span>Hands-free context next to photos and tags.</span></a>
        <a href="what-is-job-site-records.php" role="listitem"><span>What is Job Site Records?</span><span>Plain definition: capture, timeline, offline, zip export.</span></a>
    </div>

    <p class="muted" style="margin-top:28px">Homepage: <a href="/">jobsiterecords.com</a> · request early access.</p>
</div>
HTML;

render_seo_page([
    'title' => 'Resources — field documentation',
    'description' => 'Use cases, comparisons, trade notes, and copy-paste examples for contractors documenting jobs on the phone. Job Site Records.',
    'canonical_path' => '/guides/',
    'body' => $body,
    'json_ld' => $listLd,
]);
