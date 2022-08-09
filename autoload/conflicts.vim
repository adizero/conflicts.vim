function! s:GetGitMergeBuffersIfVimHasBeenInvokedAsMergeTool(list)
    let l:xs =
        \ filter(
        \   map(
        \     filter(
        \       range(1, bufnr('$')),
        \       'bufexists(v:val)'
        \     ),
        \     'bufname(v:val)'
        \   ),
        \   'v:val =~# ''_BASE_'' || v:val =~# ''_LOCAL_'' || v:val =~# ''_REMOTE_'''
        \ )

    if (len(l:xs) == 3)
        " rest of the code expects this order: base, local and remote
        " should be launches in such order from git mergetool
        call extend(a:list, l:xs)
        return 1
    endif

    return 0
endfunction

function! s:ErrorMessage(code, text)
    echohl WarningMsg
    echomsg a:text
    echohl None
    return a:code
endfunction

function! s:ReadGitMergeContentIntoLines(git_file_name, git_merge_tag, lines) abort
    if !filereadable(a:git_file_name)
        return s:ErrorMessage(1, 'File ' . a:git_file_name . ' does not exist')
    endif
    let l:git_object_name = ':' . a:git_merge_tag . ':' . a:git_file_name
    let l:lines = systemlist('git show ' . l:git_object_name)
    let l:shell_error = v:shell_error
    if l:shell_error != 0
        return s:ErrorMessage(2, 'Retrieval of git object ' . l:git_object_name . ' failed')
    endif
    call extend(a:lines, l:lines)
    return 0
endfunction

function! s:ReadGitMergeContentIntoLists(git_file_name, lists) abort
    if !filereadable(a:git_file_name)
        return s:ErrorMessage(1, 'File ' . a:git_file_name . ' does not exist')
    endif
    let l:buffer_names = []
    let l:is_vim_mergetool = s:GetGitMergeBuffersIfVimHasBeenInvokedAsMergeTool(l:buffer_names)
    " if Vim is used as the git mergetool, then the content is already in buffers named LOCAL BASE REMOTE,
    "  but the may be unloaded (we need to use readfile instead of getbufline in such cases)
    for l:git_merge_tag in [1,2,3]
        call add(a:lists, [])
        if l:is_vim_mergetool == 1
            let l:buffer_name = l:buffer_names[l:git_merge_tag - 1]
            let l:buffer_number = bufnr(l:buffer_name)
            if bufloaded(l:buffer_number)
                let l:buffer_lines = getbufline(l:buffer_number, 1, '$')
            else
                let l:buffer_lines = readfile(l:buffer_name)
            endif
            " echo l:buffer_number . ' [ '. l:buffer_name . ']'
            " echo l:buffer_lines
            call extend(a:lists[l:git_merge_tag - 1], l:buffer_lines)
        else
            let l:result = s:ReadGitMergeContentIntoLines(a:git_file_name, l:git_merge_tag, a:lists[l:git_merge_tag - 1])
            if l:result != 0
                return l:result
            endif
        endif
    endfor
    return 0
endfunction

function! s:AppendLinesToCurrentEmptyBuffer(lines) abort
    let l:failed = append(0, a:lines)
    if l:failed != 0
        return s:ErrorMessage(1, 'Appending of lines failed')
    else
        execute 'delete_'
    endif
    return 0
endfunction

function! conflicts#ShowInvolvedFilesIn3WayDiffNewTab() abort
    let l:current_buffer_file_name = expand('%')
    if !filereadable(l:current_buffer_file_name)
        return s:ErrorMessage(1, 'File ' . l:current_buffer_file_name . ' does not exist')
    endif

    let l:syntax = &syntax

    let l:lists = []
    let l:result = s:ReadGitMergeContentIntoLists(l:current_buffer_file_name, l:lists)
    if l:result != 0
        return s:ErrorMessage(2, 'Retrieval of content of involved git objects failed')
    endif

    let l:base_lines = l:lists[1 - 1]
    let l:local_lines = l:lists[2 - 1]
    let l:remote_lines = l:lists[3 - 1]

    " Create the tab and windows.
    tabnew
    vnew
    vnew
    wincmd h
    wincmd h

    " Populate each window.

    " LOCAL/HEAD
    call s:AppendLinesToCurrentEmptyBuffer(l:local_lines)
    setlocal nomodifiable readonly buftype=nofile bufhidden=delete nobuflisted
    silent execute 'file! ' . bufnr('%') . '_LOCAL/HEAD'
    let &l:syntax = l:syntax
    diffthis

    wincmd l
    " BASE/COMMON ANCESTOR
    call s:AppendLinesToCurrentEmptyBuffer(l:base_lines)
    setlocal nomodifiable readonly buftype=nofile bufhidden=delete nobuflisted
    silent execute 'file! ' . bufnr('%') . '_BASE'
    let &l:syntax = l:syntax
    diffthis

    wincmd l
    " REMOTE/MERGE_HEAD
    call s:AppendLinesToCurrentEmptyBuffer(l:remote_lines)
    setlocal nomodifiable readonly buftype=nofile bufhidden=delete nobuflisted
    silent execute 'file! ' . bufnr('%') . '_REMOTE/MERGE'
    let &l:syntax = l:syntax
    diffthis

    " Put cursor in back in BASE.
    wincmd h

    normal! gg

    return 0
endfunction

function! conflicts#ShowInvolvedFilesIn2WayDiffNewTabs() abort
    let l:current_buffer_file_name = expand('%')
    if !filereadable(l:current_buffer_file_name)
        return s:ErrorMessage(1, 'File ' . l:current_buffer_file_name . ' does not exist')
    endif

    let l:syntax = &syntax

    let l:lists = []
    let l:result = s:ReadGitMergeContentIntoLists(l:current_buffer_file_name, l:lists)
    if l:result != 0
        return s:ErrorMessage(2, 'Retrieval of content of involved git objects failed')
    endif

    let l:base_lines = l:lists[1 - 1]
    let l:local_lines = l:lists[2 - 1]
    let l:remote_lines = l:lists[3 - 1]

    " Create the tab and windows.
    tabnew
    vnew
    wincmd h

    " Populate each window.

    " BASE/COMMON ANCESTOR
    call s:AppendLinesToCurrentEmptyBuffer(l:base_lines)
    setlocal nomodifiable readonly buftype=nofile bufhidden=delete nobuflisted
    silent execute 'file! ' . bufnr('%') . '_BASE'
    let &l:syntax = l:syntax
    diffthis

    wincmd l
    " LOCAL/HEAD
    call s:AppendLinesToCurrentEmptyBuffer(l:local_lines)
    setlocal nomodifiable readonly buftype=nofile bufhidden=delete nobuflisted
    silent execute 'file! ' . bufnr('%') . '_LOCAL/HEAD'
    let &l:syntax = l:syntax
    diffthis

    " Put cursor in back in BASE.
    wincmd h

    normal! gg

    " Create the tab and windows.
    tabnew
    vnew
    wincmd h

    " BASE/COMMON ANCESTOR
    call s:AppendLinesToCurrentEmptyBuffer(l:base_lines)
    setlocal nomodifiable readonly buftype=nofile bufhidden=delete nobuflisted
    silent execute 'file! ' . bufnr('%') . '_BASE'
    let &l:syntax = l:syntax
    diffthis

    wincmd l
    " REMOTE/MERGE_HEAD
    call s:AppendLinesToCurrentEmptyBuffer(l:remote_lines)
    setlocal nomodifiable readonly buftype=nofile bufhidden=delete nobuflisted
    silent execute 'file! ' . bufnr('%') . '_REMOTE/MERGE'
    let &l:syntax = l:syntax
    diffthis

    " Put cursor in back in BASE.
    wincmd h

    normal! gg

    " Select previous tab
    normal! gT

    return 0
endfunction

function! s:HasConflictMarkers()
    try
        silent execute '%s/^<<<<<<< //gn'
        return 1
    catch /Pattern not found/
        return 0
    endtry
endfunction

function! conflicts#ShowOriginalFileWithConflictMarkersInNewTab()
	if s:HasConflictMarkers() == 0
		echohl ModeMsg
		echo 'No conflict markers found.'
		echohl None
		return 1
	endif
	let l:origBuf = bufnr('%')

	let l:syntax = &syntax

	" Set up the tab with original file with conflict markers
	tabnew
	silent execute 'read #'. l:origBuf
	1delete
	silent execute 'file! ' . bufnr('%') . '_GIT_MERGED'
	setlocal nomodifiable readonly buftype=nofile bufhidden=delete nobuflisted
	let &l:syntax = l:syntax

    normal! gg

	return 0
endfunction

function! conflicts#ChangeTo2WayDiffMode() abort
    if s:HasConflictMarkers() == 0
        echohl ModeMsg
        echo 'No conflict markers found.'
        echohl None
        return 1
    endif
    let l:origBuf = bufnr('%')

    let l:syntax = &syntax

    " Set up the left-hand side.
    topleft vsplit
    enew
    silent execute 'read #'. l:origBuf
    1delete
    silent execute 'file! ' . bufnr('%') . '_LOCAL/HEAD CONFLICT'
    silent execute "g/^=======\\r\\?$/,/^>>>>>>> /d"
    silent execute 'g/^<<<<<<< /d'
    setlocal nomodifiable readonly buftype=nofile bufhidden=delete nobuflisted
    let &l:syntax = l:syntax
    diffthis

    " Set up the right-hand side.
    wincmd p
    silent execute "g/^<<<<<<< /,/^=======\\r\\?$/d"
    silent execute 'g/^>>>>>>> /d'
    diffthis

    normal! gg

    echohl ModeMsg
    echo 'Resolve conflicts in the right side, then save. If running from git mergetool, then use :cq to abort.'
    echohl None
    return 0
endfunction

function! conflicts#ConflictsResolve() abort
    let l:result = conflicts#ShowOriginalFileWithConflictMarkersInNewTab()
    if l:result == 0
        " Select previous tab
        normal! gT
    endif
    let l:result = conflicts#ShowInvolvedFilesIn2WayDiffNewTabs()
    if l:result == 0
        " Select previous tab
        normal! gT
    endif
    let l:result = conflicts#ShowInvolvedFilesIn3WayDiffNewTab()
    if l:result == 0
        " Select previous tab
        normal! gT
    endif
    let l:result = conflicts#ChangeTo2WayDiffMode()
    if l:result != 0
        return l:result
    endif
    return 0
endfunction
