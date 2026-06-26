(function hideMembersOnly() {
    function removeMembers() {
        document.querySelectorAll('ytd-rich-grid-media, ytd-video-renderer, ytd-compact-video-renderer, ytd-grid-video-renderer').forEach(card => {
            if (card.innerText.includes('Members only')) {
                // Walk up to the grid item wrapper and hide that instead
                const gridItem = card.closest('ytd-rich-item-renderer, ytd-grid-video-renderer, ytd-video-renderer');
                const target = gridItem || card;
                target.style.setProperty('display', 'none', 'important');
            }
        });
    }

    removeMembers();
    setInterval(removeMembers, 1000);

    const observer = new MutationObserver(() => removeMembers());
    observer.observe(document.body, { childList: true, subtree: true });
})();