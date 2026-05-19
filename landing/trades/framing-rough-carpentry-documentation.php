<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Trade</span>
    <h1>Framing: the skeleton tells tales</h1>
    <p class="lead">Point loads, headers carrying actual loads, hold-downs that match the hardware schedule, fire blocking people swear they will “come back to”—shoot now. Drywall is a conspiracy against truth.</p>

    <h2>Mechanical conflicts</h2>
    <p>Notch photos (hopefully there are none), bores through plates, stacked penetrations that make inspectors sigh. Voice: “GC approved sister here—see email 3/12.”</p>

    <h2>Sheathing and bracing</h2>
    <p>Corner details, nailing pattern wide shots if spec cares. You will not reshoot this from a drone after siding.</p>

    <div class="guide-cta">
        <strong>Job Site Records</strong>
        <p>Chronological framing walks beat “camera roll Friday.”</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related"><h2>Related</h2><ul>
        <li><a href="/trades/">All trades</a></li>
        <li><a href="/use-cases/new-construction-rough-in-photo-record.php">Rough-in record</a></li>
    </ul></nav>
</article>
HTML;

render_seo_page([
    'title' => 'Framing & rough carpentry documentation',
    'description' => 'Framing photo habits: point loads, headers, hold-downs, notches, sheathing details—before drywall hides the story.',
    'canonical_path' => '/trades/framing-rough-carpentry-documentation.php',
    'body' => $body,
]);
