" ============================================================================
" File:        conflicts.vim
" Description:
" Author:      Adrian Kocis <adrian.kocis@gmail.com>
" Licence:     Vim licence
" Website:
" Version:     1.0
" Note:        Helpful functions to deal with merge/rebase conflicts in git
"              (inspired by https://github.com/whiteinge/diffconflicts)
"
" Example of how to configure this Vim plugin as git mergetool:
" git config --global merge.tool vimconflicts
" git config --global mergetool.vimconflicts.cmd 'vim -c ConflictsResolve "$MERGED" "$BASE" "$LOCAL" "$REMOTE"'
" git config --global mergetool.vimconflicts.trustExitCode true
" git config --global mergetool.keepBackup false
" ============================================================================
"
if &compatible || exists('g:loaded_conflicts_vim')
    finish
endif
let g:loaded_conflicts_vim = 1

command! ConflictsResolve :call conflicts#ConflictsResolve()
command! ConflictsDiff :call conflicts#ChangeTo2WayDiffMode()
command! ConflictsShow3WayTab :call conflicts#ShowInvolvedFilesIn3WayDiffNewTab()
command! ConflictsShow2WayTabs :call conflicts#ShowInvolvedFilesIn2WayDiffNewTabs()
" Todo: Add ConflictsTakeLocal, ConflictsTakeRemote to replace output with local, remote version completely
