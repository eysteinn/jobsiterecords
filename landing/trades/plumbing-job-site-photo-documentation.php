<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Trade</span>
    <h1>Plumbing photos that do not lie about slope</h1>
    <p class="lead">You cannot photograph “1/4 per foot” directly—you photograph context: long lens down a joist bay, laser in frame if that is your thing, cleanouts at grade before they get mulched. Pan connections and tub traps love to become theology; wide shots first.</p>

    <h2>Water tests and witnesses</h2>
    <p>Tub fill, flood test ball, shower pan flood—whatever your AHJ wants, shoot the setup and the result. Captions with time (“started 2:10p, checked 4p”) save you from astrology later.</p>

    <h2>ProPress / PEX / copper—show the work</h2>
    <p>Ring visibility, support spacing, isolation valves labeled. If it is pretty, photograph it before insulation makes it a rumor.</p>

    <div class="guide-cta">
        <strong>Job Site Records</strong>
        <p>Voice notes are great for “same layout as unit 9, mirrored.”</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related"><h2>Related</h2><ul>
        <li><a href="/trades/">All trades</a></li>
        <li><a href="/use-cases/water-damage-documentation-contractors.php">Water damage docs</a></li>
    </ul></nav>
</article>
HTML;

render_seo_page([
    'title' => 'Plumbing job site photo documentation',
    'description' => 'Plumbing field photos: DWV context, tests, ProPress/PEX evidence, captions with times for flood tests.',
    'canonical_path' => '/trades/plumbing-job-site-photo-documentation.php',
    'body' => $body,
]);
