<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Use case</span>
    <h1>Phased jobs where every unit looks the same until it does not</h1>
    <p class="lead">Apartment turns and multi-unit flips share one disease: you swear you remember which stack had the weird vent routing. You do not. The camera roll does not either because every hallway looks like every other hallway.</p>

    <h2>One job per unit—or per phase, pick a rule</h2>
    <p>Whatever you choose, enforce it. Mixing “Building A” and “Unit 304” in the same timeline is how mistakes get shipped to the wrong door.</p>

    <h2>Tags are your building vocabulary</h2>
    <p><code>Stack B</code>, <code>Phase 2</code>, <code>Hold paint</code>—boring tags beat clever ones. Voice notes are good for “same as 212 except drain left.”</p>

    <div class="guide-cta">
        <strong>Job Site Records</strong>
        <p>Separate timelines, consistent tags, zip per unit when billing.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related">
        <h2>Related</h2>
        <ul>
            <li><a href="/use-cases/">All use cases</a></li>
            <li><a href="/examples/example-crew-tag-taxonomy.php">Sample tag taxonomy</a></li>
            <li><a href="/guides/organize-job-site-photos-trades-and-tags.php">Organizing with tags</a></li>
        </ul>
    </nav>
</article>
HTML;

render_seo_page([
    'title' => 'Multi-unit & phased job tracking',
    'description' => 'Photo habits for apartment turns and phased work: one timeline per unit or phase, boring tags, voice for deltas.',
    'canonical_path' => '/use-cases/multi-unit-phased-job-tracking.php',
    'body' => $body,
]);
