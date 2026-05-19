<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$origin = site_public_origin();
$listLd = json_encode([
    '@context' => 'https://schema.org',
    '@type' => 'CollectionPage',
    'name' => 'Trade-specific job documentation',
    'url' => $origin . '/trades/',
    'isPartOf' => ['@type' => 'WebSite', 'name' => 'Job Site Records', 'url' => $origin . '/'],
], JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);

$body = <<<'HTML'
<div class="guides-list-page">
    <span class="eyebrow" style="display:block;font-size:0.78rem;font-weight:800;letter-spacing:0.12em;text-transform:uppercase;color:var(--ink-mute);margin-bottom:10px;">Trades</span>
    <h1>Same app, different superstitions</h1>
    <p class="lead">Electricians care about mud rings. Plumbers care about slope you cannot even see. Landscapers care about drainage you will definitely see in spring. The app does not change—what you point at does.</p>

    <div class="guides-grid" role="list">
        <a href="electrical-contractor-field-documentation.php" role="listitem"><span>Electrical</span><span>Panels, derate stickers, temp power, “before you bury it.”</span></a>
        <a href="plumbing-job-site-photo-documentation.php" role="listitem"><span>Plumbing</span><span>ProPress rings, pan liners, vent terminations people argue about.</span></a>
        <a href="remodeling-kitchen-bath-progress-photos.php" role="listitem"><span>Remodel (kitchen &amp; bath)</span><span>Cabinets, tile lippage, waterproofing corners owners never notice until they do.</span></a>
        <a href="landscaping-hardscape-progress-photos.php" role="listitem"><span>Landscaping &amp; hardscape</span><span>Drainage, pitch, base prep—photos that survive winter.</span></a>
        <a href="hvac-startup-commissioning-photos.php" role="listitem"><span>HVAC startup</span><span>Nameplates, line sets, condensate routes, filter access reality.</span></a>
        <a href="painting-drywall-finish-documentation.php" role="listitem"><span>Painting &amp; drywall</span><span>Flash angles, primer vs topcoat, nail pops that come back like zombies.</span></a>
        <a href="concrete-flatwork-foundation-photo-records.php" role="listitem"><span>Concrete &amp; foundations</span><span>Rebar chairing, pour weather, control joints, anchor bolts.</span></a>
        <a href="roofing-installation-job-photos.php" role="listitem"><span>Roofing</span><span>Ice shield laps, nail lines, penetrations, gutter handoffs.</span></a>
        <a href="framing-rough-carpentry-documentation.php" role="listitem"><span>Framing &amp; rough carpentry</span><span>Point loads, headers, hardware schedules nobody reads until inspection.</span></a>
        <a href="low-voltage-av-fiber-rough-in-photos.php" role="listitem"><span>Low voltage &amp; AV</span><span>Smurf, bend radius jokes, rack dress rehearsal.</span></a>
    </div>

    <p class="muted" style="margin-top:28px"><a href="/guides/">All resources</a></p>
</div>
HTML;

render_seo_page([
    'title' => 'Trade-specific documentation',
    'description' => 'Field photo habits by trade: electrical, plumbing, remodel, landscape, HVAC, paint, concrete, roofing, framing, low voltage.',
    'canonical_path' => '/trades/',
    'body' => $body,
    'json_ld' => $listLd,
]);
