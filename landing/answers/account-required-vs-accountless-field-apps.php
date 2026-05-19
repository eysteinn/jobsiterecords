<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Comparison</span>
    <h1>“Create an account” is a personality test</h1>
    <p class="lead">Some people read “sign up” and think security. Crews often read it as “this company is about to own my photos.” Both reactions are fair depending on history. Account-less apps trade admin convenience for trust speed—you install and shoot.</p>

    <h2>Accounts help when</h2>
    <p>You are revoking access, billing a workspace, or syncing devices. You need identity. Fine.</p>

    <h2>No account helps when</h2>
    <p>You are trying to get six people documenting without a rollout meeting. The phone stays the vault until export.</p>

    <div class="guide-cta">
        <strong>Job Site Records</strong>
        <p>Phase 1 skips mandatory sign-in; optional accounts ride with the later team tier.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related">
        <h2>Related</h2>
        <ul>
            <li><a href="/answers/">All answers</a></li>
            <li><a href="/guides/local-first-construction-app-no-account.php">Local-first, no account (guide)</a></li>
        </ul>
    </nav>
</article>
HTML;

render_seo_page([
    'title' => 'Account required vs account-less field apps',
    'description' => 'When construction apps should require accounts vs when skipping sign-in speeds adoption and keeps media local.',
    'canonical_path' => '/answers/account-required-vs-accountless-field-apps.php',
    'body' => $body,
]);
