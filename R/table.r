require('stringr')
require('xtable')

dev.copy2png <- function(file, ...) {
     dev.copy(png, file = file,  bg = "white", ...)
     dev.off()
 }

systemic.units.latex <- c(period='[days]', mass='[$\\mass_{jup}$]', ma='[deg]', ecc='',
                         lop='[deg]', inc='[deg]', node='[deg]',
                         a='[AU]', k='[$\\mathrm{m s}^{-1}$]', tperi='[JD]',
                         rv.trend='[$\\mathrm{m s}^{-1}$]', rv.trend.quadratic='[$\\mathrm{m s}^{-1}$^2]',
                         mstar = '[$\\mass_\\odot$]', chi2='', jitter='[$\\mathrm{m s}^{-1}$]', rms='[$\\mathrm{m s}^{-1}$]',
                         epoch = '[JD]', ndata='', trange='[JD]', loglik='', chi2nr='')
for (i in 1:10)
    systemic.units.latex[sprintf('data.noise%d', i)] <- '[$\\mathrm{m s}^{-1}$]'


nformat <- function(n, err=0, digits=3, fmt="%s [%s]") {
    if (err != 0) {
        e10 <- floor(log10(abs(err)))
        if (e10 > 0) {
            err <- round(err)
            n <- round(n)
        } else {
            fmt2 <- sprintf("%%.%df", -e10)            
            err <- sprintf(fmt2, round(err, -e10))
            n <- sprintf(fmt2, round(n, -e10))
        }
        return(sprintf(fmt, n, err))
    } else {
        if (floor(n) == n)
            n <- sprintf("%d", n)
        else
            n <- sprintf(sprintf("%%.%df", digits), n)

        return(n)
    }
}

ktable <- function(k, what=c('period', 'mass', 'ma', 'ecc', 'lop', 'k', 'a', 'tperi', '-', 'mstar', 'chi2nr', 'loglik', 'rms', 'jitter', 'epoch', 'ndata', 'trange', 'pars.minimized'), labels=systemic.names, units=if (!latex) systemic.units else systemic.units.latex, caption=NULL, star.names=NULL, default.format="%.2f", default.nf="%s [%s]", latex=FALSE, sep.length=15) {
    systemic.names <- labels
    systemic.units <- units
    
    if (class(k) == 'kernel')
        k <- list(k)
    if (is.null(star.names))
        star.names <- rep('', length(k))
    if (length(star.names) != length(k))
        stop("There are more kernels than star names")
    
    df <- data.frame()
    
    if ('pars.minimized' %in% what) {
        idx <- which(what == 'pars.minimized')
        parnames <- lapply(k, function(k) {
            p <- kflags(k)$par
            p <- p[p == bitOr(ACTIVE, MINIMIZE)]
            p <- p[!is.na(systemic.names[names(p)])]
            return(names(p))
        })
        
        if (length(parnames[[1]]) > 0) {
            what <- c(what[-idx], unlist(parnames))
        } else
            what <- what[-idx]
    }
    
    planet.labels <- unlist(lapply(1:length(k), function(i) str_join(star.names[i], letters[1+1:k[[i]]$nplanets])))
    
    row.labels <- sapply(what, function(n) {
        if (n == '-')
            return('-')
        else
            sprintf("%s %s", systemic.names[n], systemic.units[n])
    })

    sep <- str_join(rep('—', sep.length), collapse='')
    row.labels[row.labels == '-'] <- sep
    
    df <- matrix('', nrow=length(row.labels), ncol=length(planet.labels))
    colnames(df) <- planet.labels
    rownames(df) <- row.labels

    col <- 1
    for (i in 1:length(k)) {
        kk <- k[[i]]
        if (is.null(kk$errors))
            warning(sprintf("[Warning: Errors were not calculated for kernel #%d]\n", i))

        for (pl in 1:kk$nplanets) {
            for (j in 1:length(what)) {

                if (what[j] == '-') {
                    df[j, col] <- sep
                    next
                }
                    
                if (systemic.type[what[j]] == ELEMENT) {
                    if (!is.null(kk$errors)) 
                        df[j, col] <- nformat(kk$errors$stats[[pl]][what[j], 'median'],
                                             kk$errors$stats[[pl]][what[j], 'mad'], fmt=default.nf)
                    else
                        df[j, col] <- nformat(kk[pl, what[j]])
                    
                }

                if (pl > 1)
                    next
                
                if (systemic.type[what[j]] == PARAMETER) {
                    if (!is.null(kk$errors))
                        df[j, col] <- nformat(kk$errors$params.stats[what[j], 'median'],
                                             kk$errors$params.stats[what[j], 'mad'])
                    else
                        df[j, col] <- nformat(kk['par', what[j]])
                    
                } else if (systemic.type[what[j]] == PROPERTY) {
                    
                    p <- kget(kk, what[j])
                    if (what[j] == 'trange') {
                        p <- paste(nformat(p[1]), nformat(p[2]-p[1]), sep='+')
                    } else {
                        if (length(p) > 1)
                            p <- str_join(sapply(p, nformat), collapse=' - ')
                        else
                            p <- nformat(p)
                    }
                    df[j, col] <- p
                }
            }
            col <- col+1
        }        
    }

    class(df) <- c('systemic.table', 'matrix')
    attr(df, 'latex') <- latex
    attr(df, 'caption') <- caption
    
    return(df)
}

.systemic.table.display <- function(df) {
    class(df) <- "matrix"
    df <- gsub("(\\\\pm\\{\\})", "+-", df)
    df <- gsub("(\\\\times)", "x", df)
    rownames(df) <- gsub("[\\{\\}]", "", rownames(df))
    attr(df, 'latex') <- NULL
    attr(df, 'caption') <- NULL
    
    return(df)
}

print.systemic.table <- function(df, file=stdout(), type=NA, caption=NULL, font.size="normalsize") {
    if (any(class(file) == "character")) {
        file <- file(file) 
        on.exit(close(file))
    }
    
    if (is.na(type)) {
        if (!attr(df, 'latex'))
            type = 'text'
        else
            type = 'latex'
    }
    if (type == "text") {
        sink(file)
        cat("\n")
        print(noquote(.systemic.table.display(df)))
        cat("\n")
        if (file != stdout())
            sink()
        return(invisible())
    } else if (type == "latex") {
        s <- paste(toLatex(xtable(df, caption=attr(df, 'caption'))), collapse='\n')
        s <- str_replace_all(s, "(——.+?)\\\\", "\\\\hline")
        s <- str_replace(s, "\\centering", paste("\\centering\\\\", font.size, sep=''))
        cat(s, file=file)
        return(invisible(s))
    }
}

plot.systemic.table <- function(df, ...) {
    oldpar <- par(no.readonly=TRUE)
    on.exit(par(oldpar))
    textplot(.systemic.table.display(df), ...)
}

.append.figure <- function(file, width, height) {
    dev.copy2pdf(file, width, height)
}

latex.report <- function(k, where=stop("Specify a folder where to save the file."), trials=1e4,  report.file=str_join(getOption('systemic.path'), '/report.tex')) {
    cur <- getwd()
    on.exit(setwd(cur))
    setwd(where)

    file.copy(report.file, getwd(), overwrite=FALSE)
    if (is.null(k$filename))
        fn <- 'bestfit.fit'
    else
        fn <- basename(k$filename)
    ksave(k, fn)
    print(ktable(k, latex=TRUE), file='table.tex', font.size='small', caption='Best fit')
    
    if (is.null(k$p)) {
        cat("Calculating periodogram...\n")
        k$p <- kperiodogram.boot(k, trials=1e4)
        saveRDS(k$p, 'periodogram.rds')
    }
    par(default.par)
    plot(k$p, show.resampled=TRUE)
    dev.copy2pdf(file='periodogram.pdf', width=8, height=6)
    dev.copy2png(file='periodogram.png', units='in', width=8, height=6, res=300)

    par(default.par)

    if (is.null(k$r)) {
        cat("Calculating periodogram of residuals...\n")
        k$r <- kperiodogram.boot(k, 'res', trials=trials)
        saveRDS(k$r, 'periodogram_residuals.rds')
    }
    par(default.par)
    plot(k$r, show.resampled=TRUE)
    dev.copy2pdf(file="residuals.pdf", width=8, height=6)
    dev.copy2png(file='residuals.png', units='in', width=8, height=6, res=300)
    par(default.par)
    cat(file='residuals.tex', paste(toLatex(xtable(k$r, caption='Residuals periodogram')), collapse='\n'))

    if (is.null(k$integration)) {
        cat("Integrating for 10,000 years...\n")
        k$integration <- kintegrate(k, 1e4 * 365.25, RK89)
        saveRDS(k$integration, 'integration.rds')
    }

    par(default.par)
    plot(k$integration, show.resampled=TRUE)
    dev.copy2pdf(file="integration.pdf", width=9, height=12)
    par(default.par)

    par(default.par)
    plot(k)
    dev.copy2pdf(file="fit.pdf", width=8, height=12)
    par(default.par)
    
    par(default.par)
    plot(k, 'allrv', wrap=TRUE, plot.residuals=FALSE)
    dev.copy2pdf(file="fit_wrap.pdf", width=4 * (floor(k$nplanets/4)+1), height=3 * min(k$nplanets, 4))
    par(default.par)

    if (is.null(k$errors)) {
        par(default.par)
        par(mar=c(0, 0, 0, 0))
        plot.orbit(k)
        dev.copy2pdf(file='orbit.pdf', width=8, height=8)
        par(default.par)
    } else {
        par(default.par)
        par(mar=c(0, 0, 0, 0))
        plot.orbit(k$errors)
        dev.copy2pdf(file='orbit.pdf', width=8, height=8)
        par(default.par)
    }

    system("pdflatex report.tex")
    
}

options(xtable.sanitize.text.function=function(x) x)

xtable.periodogram <- function(p, ...) {
    p <- attr(p, 'peaks')
    p <- p[1:min(nrow(p), 10), c(1, 2, 3, 6)]
    display <- rep('f', ncol(p)+1)
    display[4] <- 'e'
    display[1] <- 'd'
    return(xtable(p, display=display, ...))
}