<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Comparison</span>
    <h1>Enterprise pricing vs buying sandwiches for the crew</h1>
    <p class="lead">Platforms priced per seat per month make sense when seats sit in offices and churn is low. When your “seat” is whichever phone slid into a muddy pocket today, math gets silly fast. Free local capture is not charity—it is a different assumption about who pays for value.</p>

    <h2>Enterprise buys governance</h2>
    <p>SSO, audit trails, integrations. If you need those letters, pay for them.</p>

    <h2>Local-first buys speed</h2>
    <p>Install, shoot, export. Upsell later for teams that actually asked for sync—not on day zero when you are still proving the habit.</p>

    <div class="guide-cta">
        <strong>Job Site Records</strong>
        <p>Free local path; paid tier later for teams who want sync and dashboards—see roadmap on the homepage FAQ.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related">
        <h2>Related</h2>
        <ul>
            <li><a href="/answers/">All answers</a></li>
            <li><a href="/guides/job-site-records-free-vs-pro-teams.php">Free vs Pro teams</a></li>
        </ul>
    </nav>
</article>
HTML;

render_seo_page([
    'title' => 'Free local documentation vs enterprise platforms',
    'description' => 'Seat pricing vs free local capture: when enterprise construction software earns its cost—and when lightweight tools fit.',
    'canonical_path' => '/answers/free-local-documentation-vs-enterprise-platforms.php',
    'body' => $body,
]);
