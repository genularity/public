// Reading progress bar — injected into every content page
document.addEventListener("nav", () => {
  // Create bar element if it doesn't exist yet
  let bar = document.getElementById("reading-progress")
  if (!bar) {
    bar = document.createElement("div")
    bar.id = "reading-progress"
    document.body.prepend(bar)
  }

  const update = () => {
    const scrollTop = window.scrollY
    const docHeight = document.documentElement.scrollHeight - window.innerHeight
    const progress = docHeight > 0 ? (scrollTop / docHeight) * 100 : 0
    bar!.style.width = `${Math.min(progress, 100)}%`
  }

  window.addEventListener("scroll", update, { passive: true })
  update()
})
