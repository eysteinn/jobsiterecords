<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Use case</span>
    <h1>Warranty calls you can smell coming</h1>
    <p class="lead">Nobody wins a warranty fight with vibes. You win with a boring trail: what you touched, what you left as-is, what the owner signed off on visually. The goal is not to be right loudly—it is to be right in one email attachment.</p>

    <h2>Shoot the ugly on purpose</h2>
    <p>Scratches that pre-existed. Concrete that already had crazing. Paint lines that were never going to be laser straight because the drywall wave lives rent-free in old houses. If you only photograph the pretty angles, you invited the argument.</p>

    <h2>Punch walks need a system, not a mood</h2>
    <p>Same room order every time. Wide then tight. Tag <code>Issue</code> vs <code>Done</code> so your future self is not decoding filenames at 10pm. Voice note while you walk if your thumb is cold—just say room + item + who is responsible.</p>

    <div class="guide-cta">
        <strong>Job Site Records</strong>
        <p>Tags + voice + zip export—built for “prove it” weeks.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related">
        <h2>Related</h2>
        <ul>
            <li><a href="/use-cases/">All use cases</a></li>
            <li><a href="/examples/example-client-closeout-photo-checklist.php">Closeout photo checklist</a></li>
            <li><a href="/guides/construction-defect-documentation-checklist.php">Defect checklist (guide)</a></li>
        </ul>
    </nav>
</article>
HTML;

render_seo_page([
    'title' => 'Warranty & punch list photo trail',
    'description' => 'Build a warranty-friendly photo habit: document pre-existing issues, punch walks with tags, export a clean trail.',
    'canonical_path' => '/use-cases/warranty-punch-list-photo-trail.php',
    'body' => $body,
]);
