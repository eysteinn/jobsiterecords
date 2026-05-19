<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$origin = site_public_origin();
$listLd = json_encode([
    '@context' => 'https://schema.org',
    '@type' => 'CollectionPage',
    'name' => 'Job documentation use cases',
    'url' => $origin . '/use-cases/',
    'isPartOf' => ['@type' => 'WebSite', 'name' => 'Job Site Records', 'url' => $origin . '/'],
], JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);

$body = <<<'HTML'
<div class="guides-list-page">
    <span class="eyebrow" style="display:block;font-size:0.78rem;font-weight:800;letter-spacing:0.12em;text-transform:uppercase;color:var(--ink-mute);margin-bottom:10px;">Use cases</span>
    <h1>When the phone is the clipboard</h1>
    <p class="lead">These are the situations where crews actually stick with a photo habit—because something is on the line: a picky homeowner, a GC who loses email, an inspector who wants receipts, or a Tuesday afternoon where nobody agrees what “done” meant last week.</p>

    <div class="guides-grid" role="list">
        <a href="remodel-progress-photos-for-homeowners.php" role="listitem"><span>Remodel progress for homeowners</span><span>Updates that do not turn into a second job.</span></a>
        <a href="offline-job-photo-app-small-contractors.php" role="listitem"><span>Offline photos for small contractors</span><span>Basements, metal buildings, rural jobs—no bars, still a paper trail.</span></a>
        <a href="warranty-punch-list-photo-trail.php" role="listitem"><span>Warranty &amp; punch list trails</span><span>So “it was like that when we left” is not a personality trait.</span></a>
        <a href="water-damage-documentation-contractors.php" role="listitem"><span>Water damage documentation</span><span>Moisture, tear-out, dry-in—without turning your phone into a lawyer.</span></a>
        <a href="commercial-ti-field-documentation.php" role="listitem"><span>Commercial TI field notes</span><span>Landlord photos, after-hours work, ceiling grid realities.</span></a>
        <a href="new-construction-rough-in-photo-record.php" role="listitem"><span>New construction rough-in records</span><span>What goes in the wall before it does not come back out.</span></a>
        <a href="residential-closeout-handover-photos.php" role="listitem"><span>Residential closeout &amp; handover</span><span>Scratches, paint, caulk, manuals—boring wins.</span></a>
        <a href="safety-site-walk-documentation.php" role="listitem"><span>Safety walk photos</span><span>Housekeeping, access, sketchy ladder setups—your own receipts.</span></a>
        <a href="multi-unit-phased-job-tracking.php" role="listitem"><span>Multi-unit &amp; phased jobs</span><span>When unit 304 and 412 are not the same story.</span></a>
        <a href="payment-protection-documentation-for-subs.php" role="listitem"><span>Payment protection for subs</span><span>Not legal advice—just habits that keep arguments shorter.</span></a>
    </div>

    <p class="muted" style="margin-top:28px"><a href="/guides/">All resources</a> · <a href="/">Home</a></p>
</div>
HTML;

render_seo_page([
    'title' => 'Use cases — job site documentation',
    'description' => 'Practical use cases: remodel updates, offline capture, punch lists, TI work, rough-in, closeout, phased jobs, and field evidence for contractors.',
    'canonical_path' => '/use-cases/',
    'body' => $body,
    'json_ld' => $listLd,
]);
