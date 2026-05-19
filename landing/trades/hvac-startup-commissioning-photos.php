<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Trade</span>
    <h1>HVAC photos that survive the first heat wave blame game</h1>
    <p class="lead">Nameplates, breaker pairing, disconnect install height drama, line set protection where scissor lifts roam—get boring evidence while it is still accessible. Attics hate humans later.</p>

    <h2>Condensate is a movie genre</h2>
    <p>Show primary and backup routes, pump if any, where it terminates. Nobody wants to discover it tees into something spiritually wrong behind a furnace.</p>

    <h2>Startup readings deserve a friend</h2>
    <p>If you log pressures or temps, photo the gauges with context in the caption. Future texts will thank you in fewer words.</p>

    <div class="guide-cta">
        <strong>Job Site Records</strong>
        <p>Voice + photo pairs well for “subcool was X, ambient was trash, customer refused shade mesh.”</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related"><h2>Related</h2><ul>
        <li><a href="/trades/">All trades</a></li>
        <li><a href="/use-cases/new-construction-rough-in-photo-record.php">Rough-in photos</a></li>
    </ul></nav>
</article>
HTML;

render_seo_page([
    'title' => 'HVAC startup & commissioning photos',
    'description' => 'HVAC field photo habits: nameplates, line sets, condensate routing, disconnects, gauge readings with captions.',
    'canonical_path' => '/trades/hvac-startup-commissioning-photos.php',
    'body' => $body,
]);
