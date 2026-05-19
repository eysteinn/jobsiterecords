<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Use case</span>
    <h1>TI work when the building is still half awake</h1>
    <p class="lead">Tenant improvements are weird: you are a guest in someone else’s house rules—after-hours noise clauses, loading dock politics, ceiling grid you cannot mark up “temporarily.” Photos become the memo nobody wanted to write.</p>

    <h2>What GCs quietly want</h2>
    <p>Above-ceiling shots before you close tiles. Photos of existing MEP you had to dodge. Proof you left fire caulk where spec said so. Not glamorous. Very email-forwardable.</p>

    <h2>Signal is never guaranteed</h2>
    <p>Core buildings love killing phone service. Capture offline, export when you hit real Wi-Fi, and stop apologizing for “I’ll send pics tonight.”</p>

    <div class="guide-cta">
        <strong>Job Site Records</strong>
        <p>Per-job evidence, zip handoff, no cloud requirement in Phase 1.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related">
        <h2>Related</h2>
        <ul>
            <li><a href="/use-cases/">All use cases</a></li>
            <li><a href="/examples/sample-rough-in-email-to-gc.php">Sample rough-in email</a></li>
            <li><a href="/guides/subcontractor-to-gc-documentation-handoff.php">Sub to GC handoff</a></li>
        </ul>
    </nav>
</article>
HTML;

render_seo_page([
    'title' => 'Commercial TI field documentation',
    'description' => 'Photo habits for tenant improvement work: above-ceiling proof, existing conditions, offline capture for bad-building signal.',
    'canonical_path' => '/use-cases/commercial-ti-field-documentation.php',
    'body' => $body,
]);
