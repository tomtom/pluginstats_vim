" @Author:      Tom Link (micathom AT gmail com?subject=[vim])
" @GIT:         http://github.com/tomtom/vimtlib/
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Revision:    79
" GetLatestVimScripts: 0 0 :AutoInstall: pluginstats.vim
" Provide statistics how often a source file was loaded

if &cp || exists("loaded_pluginstats")
    finish
endif
let loaded_pluginstats = 1

let s:save_cpo = &cpo
set cpo&vim


if !exists('g:pluginstats_file')
    " The filename of the data file.
    let g:pluginstats_file = split(&rtp, ',')[0] .'/pluginstats.data'   "{{{2
endif


if !exists('g:pluginstats_ignore_rx')
    " Ignore filenames matching this |regexp|.
    let g:pluginstats_ignore_rx = '\([\/]vim[\/]vim\d\+[\/]\|[\/]after[\/]\|[\/][._]\?g\?vimrc$\)'   "{{{2
endif


if !exists('g:pluginstats_sort')
    " If true, sort the report by count.
    let g:pluginstats_sort_by_count = 1   "{{{2
endif


if !exists('g:pluginstats_autoexport')
    " If > 0, automatically export the report as CSV file every N days.
    let g:pluginstats_autoexport = 0   "{{{2
endif


if !exists('g:pluginstats_sep')
    let g:pluginstats_sep = ";"   "{{{2
endif


" Create a report.
command! Pluginstats call s:Report()

" Reset all stats.
command! PluginstatsReset call s:Reset()


let s:session_files = {}

function! s:Register(file) "{{{3
    " TLogVAR a:file
    if a:file !~ g:pluginstats_ignore_rx && !has_key(s:session_files, a:file)
        let s:data[a:file] = get(s:data, a:file, 0) + 1
        let s:session_files[a:file] = 1
    endif
endf


function! s:FormatData() "{{{3
    let n = get(s:data, "*RUNS*", 0)
    if n > 0
        let data = copy(s:data)
        let all_files = split(globpath(&rtp, "plugin/*.vim"), '\n')
        " let all_files += split(globpath(&rtp, "autoload/**/*.vim"), '\n')
        for file in all_files
            if file !~ g:pluginstats_ignore_rx && !has_key(data, file)
                let data[file] = 0
            endif
        endfor
        call remove(data, '*RUNS*')
        call remove(data, '*LAST-EXPORT*')
        let files = items(data)
        if g:pluginstats_sort_by_count
            let files = sort(files, 's:FileSorter')
        else
            let files = sort(files)
        endif
        let files = map(files, 's:FileProcess(v:val, n)')
        call insert(files, printf("Script%sCount%sPct", g:pluginstats_sep, g:pluginstats_sep))
        return files
    else
        return []
    endif
endf


function! s:Report() "{{{3
    let lines = s:FormatData()
    if !empty(lines)
        exec 'drop' fnameescape(s:ReportFile())
        let b:delimiter = ';'
        1,$delete
        call append(0, lines)
    endif
endf


function! s:ReportFile() "{{{3
    return fnamemodify(g:pluginstats_file, ':p:h') .'/pluginstats.csv'
endf


function! s:FileSorter(f1, f2) "{{{3
    let n1 = a:f1[0]
    let n2 = a:f2[0]
    let i1 = str2nr(a:f1[1])
    let i2 = str2nr(a:f2[1])
    return i1 == i2 ? (n1 == n2 ? 0 : n1 > n2 ? 1 : -1) : i1 > i2 ? -1 : 1
endf


function! s:FileProcess(filedef, n) "{{{3
    let [filename, times] = a:filedef
    let filename = '"'. escape(filename, '"') .'"'
    let pct = times * 100 / a:n
    let desc = printf("%s%s%d%s%4.2f%%", filename, g:pluginstats_sep, times, g:pluginstats_sep, pct)
    return desc
endf


function! s:Initialize() "{{{3
    if !exists('s:data')
        " TLogVAR g:pluginstats_file
        if filereadable(g:pluginstats_file)
            let datalines = readfile(g:pluginstats_file)
            let s:data = eval(join(datalines, "\n"))
            let s:data['*RUNS*'] += 1
            call s:RegisterScriptnames()
        else
            call s:Reset()
        endif
    endif
endf


function! s:Exit() "{{{3
    if exists('s:data')
        if g:pluginstats_autoexport > 0
            let days = localtime() / (60 * 60 * 24)
            if days != s:data['*LAST-EXPORT*'] && days % g:pluginstats_autoexport == 0
                let s:data['*LAST-EXPORT*'] = days
                let lines = s:FormatData()
                if !empty(lines)
                    let report = s:ReportFile()
                    call writefile(lines, report)
                    silent echom "PluginStats: Write report to" report
                endif
            endif
        endif
        let datastring = string(s:data)
        call writefile([datastring], g:pluginstats_file)
    endif
endf


function! s:Reset() "{{{3
    if filereadable(g:pluginstats_file)
        call delete(g:pluginstats_file)
    endif
    let s:data = {'*RUNS*': 1, '*LAST-EXPORT*': 0}
    call s:RegisterScriptnames()
endf


function! s:RegisterScriptnames() "{{{3
    redir => scriptss
    silent scriptnames
    redir END
    let scripts = split(scriptss, '\n')
    let scripts = map(scripts, 'matchstr(v:val, ''^\s*\d\+:\s\+\zs.*$'')')
    for file in scripts
        call s:Register(file)
    endfor
endf


augroup PluginStats
    autocmd!
    autocmd VimLeavePre * call s:Exit()
    autocmd SourcePre * call s:Register(expand("<afile>:p"))
augroup END

call s:Initialize()


let &cpo = s:save_cpo
unlet s:save_cpo
