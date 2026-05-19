<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$origin = site_public_origin();
$listLd = json_encode([
    '@context' => 'https://schema.org',
    '@type' => 'CollectionPage',
    'name' => 'Templates & examples — job site documentation',
    'url' => $origin . '/examples/',
    'isPartOf' => ['@type' => 'WebSite', 'name' => 'Job Site Records', 'url' => $origin . '/'],
], JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);

$body = <<<'HTML'
<div class="guides-list-page">
    <span class="eyebrow" style="display:block;font-size:0.78rem;font-weight:800;letter-spacing:0.12em;text-transform:uppercase;color:var(--ink-mute);margin-bottom:10px;">Examples</span>
    <h1>Steal shamelessly, then edit</h1>
    <p class="lead">These are starter blocks—fake addresses, fake GC names, real-world shapes. If a line makes you cringe, good: that means you are awake. Rewrite until it sounds like your crew, not like marketing.</p>

    <div class="guides-grid" role="list">
        <a href="sample-weekly-homeowner-update-email.php" role="listitem"><span>Weekly homeowner email</span><span>Short, photo-forward, not a novel.</span></a>
        <a href="example-change-order-photo-sequence.php" role="listitem"><span>Change order photo sequence</span><span>Wide → medium → tight, with captions.</span></a>
        <a href="example-handoff-zip-contents-checklist.php" role="listitem"><span>Handoff zip checklist</span><span>What goes in the folder so people stop asking.</span></a>
        <a href="example-remodel-week-caption-list.php" role="listitem"><span>Caption list (one kitchen week)</span><span>Copy/paste lines you can bend.</span></a>
        <a href="example-crew-tag-taxonomy.php" role="listitem"><span>Tag taxonomy for a four-person crew</span><span>Boring on purpose.</span></a>
        <a href="example-short-field-voice-note-script.php" role="listitem"><span>30-second voice script</span><span>Room, fact, impact, next step.</span></a>
        <a href="example-three-day-job-log-entries.php" role="listitem"><span>Three-day job log snippets</span><span>What “good enough” looks like.</span></a>
        <a href="sample-rough-in-email-to-gc.php" role="listitem"><span>Rough-in email to GC</span><span>Attach the zip, mean it.</span></a>
        <a href="example-defect-bullet-list-for-gc.php" role="listitem"><span>Defect list bullets</span><span>Tight list, not a manifesto.</span></a>
        <a href="example-client-closeout-photo-checklist.php" role="listitem"><span>Client closeout photo checklist</span><span>Walk order you can reuse.</span></a>
    </div>

    <p class="muted" style="margin-top:28px"><a href="/guides/">All resources</a></p>
</div>
HTML;

render_seo_page([
    'title' => 'Templates & examples',
    'description' => 'Copy-ready examples: homeowner updates, GC emails, captions, tags, voice scripts, job logs, handoff checklists.',
    'canonical_path' => '/examples/',
    'body' => $body,
    'json_ld' => $listLd,
]);
