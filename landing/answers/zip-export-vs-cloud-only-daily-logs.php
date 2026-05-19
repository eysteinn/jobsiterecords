<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Comparison</span>
    <h1>Zip export vs living in someone else’s cloud</h1>
    <p class="lead">Cloud logs are slick until the subscription lapses, the intern deletes a project, or you need a package a year later and the API mood changed. A zip is rude, chunky, and gloriously portable—it is yours in a folder like it is 2009 and that is sometimes exactly what legal likes.</p>

    <h2>Cloud shines for collaboration</h2>
    <p>Real-time comments, simultaneous viewers, permissions—that is not zip’s game. Zip is a handoff artifact: “here is the bundle, do what you want with it.”</p>

    <h2>Zip shines for ownership</h2>
    <p>Email to yourself, drop on NAS, AirDrop to the owner. No account recovery drama. The tradeoff is you must mean it when you export—nothing magic syncs unless you build that habit.</p>

    <div class="guide-cta">
        <strong>Job Site Records</strong>
        <p>Phase 1 ends in a zip you control. Optional team sync is a later chapter for orgs that want both worlds.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related">
        <h2>Related</h2>
        <ul>
            <li><a href="/answers/">All answers</a></li>
            <li><a href="/guides/export-job-site-zip-html-csv.php">What is inside the zip</a></li>
        </ul>
    </nav>
</article>
HTML;

render_seo_page([
    'title' => 'Zip export vs cloud-only daily logs',
    'description' => 'Zip handoffs vs cloud-only construction logs: ownership, collaboration, and when each approach earns its keep.',
    'canonical_path' => '/answers/zip-export-vs-cloud-only-daily-logs.php',
    'body' => $body,
]);
