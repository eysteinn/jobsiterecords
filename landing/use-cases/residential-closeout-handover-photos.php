<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Use case</span>
    <h1>Closeout photos that do not insult the homeowner</h1>
    <p class="lead">Handover day is not the time to discover you never photographed the scratch behind the pantry door. Owners are tired. You are tired. A tight closeout set is basically empathy with a timestamp.</p>

    <h2>Walk like a picky human</h2>
    <p>Start where they enter every day—mudroom, kitchen, main bath. Flash on for paint at angles people actually see from the sofa. Open every drawer you installed. Shoot breaker directory if you touched power. Appliances level in frame—nobody wants the “is it supposed to lean?” text two weeks later.</p>

    <h2>Zip beats “check the drive link again”</h2>
    <p>One archive, readable index, done. Email can die; attachments are rude but honest.</p>

    <div class="guide-cta">
        <strong>Job Site Records</strong>
        <p>Curate a job, export a zip, move on with your life.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related">
        <h2>Related</h2>
        <ul>
            <li><a href="/use-cases/">All use cases</a></li>
            <li><a href="/examples/example-handoff-zip-contents-checklist.php">Handoff zip checklist</a></li>
            <li><a href="/trades/remodeling-kitchen-bath-progress-photos.php">Kitchen &amp; bath remodel</a></li>
        </ul>
    </nav>
</article>
HTML;

render_seo_page([
    'title' => 'Residential closeout & handover photos',
    'description' => 'Closeout photo walk habits: kitchens, baths, paint at real angles, panels, zip handoff instead of flaky links.',
    'canonical_path' => '/use-cases/residential-closeout-handover-photos.php',
    'body' => $body,
]);
