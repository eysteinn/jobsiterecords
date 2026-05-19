<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Comparison</span>
    <h1>Team photo apps vs “just get it in the folder”</h1>
    <p class="lead">Cloud-first photo tools can be great when the whole company lives there—PMs, supers, owners on retainer. They also turn into the app people stop opening when upload bars show up in a basement with no bars. Job Site Records sits in the second camp on purpose: local capture first, zip out when you are ready.</p>

    <h2>When the big tool wins</h2>
    <p>You need multi-user permissions, cross-job reporting, and a billing contact who loves dashboards. Buy the heavy thing. No shade.</p>

    <h2>When the light tool wins</h2>
    <p>Two trucks, no IT, jobs where signal is fiction. You still need discipline—tags, captions—but you do not need a login wall before the first photo of a leak.</p>

    <table>
        <thead><tr><th>If this sounds like you…</th><th>Lean toward…</th></tr></thead>
        <tbody>
            <tr><td>Whole office coordinates daily in one system</td><td>Team cloud product</td></tr>
            <tr><td>Crews rotate phones, hate passwords, work offline</td><td>Local-first capture + zip</td></tr>
        </tbody>
    </table>

    <p>We are building Job Site Records for the second row—not because the first row is wrong, but because it already has plenty of vendors yelling about it.</p>

    <div class="guide-cta">
        <strong>Try our shape</strong>
        <p>Early access: <a href="/#waitlist">request on the homepage</a>.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related">
        <h2>Related</h2>
        <ul>
            <li><a href="/answers/">All answers</a></li>
            <li><a href="/answers/free-local-documentation-vs-enterprise-platforms.php">Free local vs enterprise</a></li>
        </ul>
    </nav>
</article>
HTML;

render_seo_page([
    'title' => 'Job Site Records vs team photo apps',
    'description' => 'When cloud team photo tools fit—and when local-first zip export fits better for small crews and bad signal.',
    'canonical_path' => '/answers/job-site-records-vs-field-photo-apps.php',
    'body' => $body,
]);
