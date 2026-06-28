import { QuartzComponent, QuartzComponentConstructor, QuartzComponentProps } from "./types"
import readingProgressScript from "./scripts/readingProgress.inline"

const Body: QuartzComponent = ({ children }: QuartzComponentProps) => {
  return <div id="quartz-body">{children}</div>
}

Body.afterDOMLoaded = readingProgressScript

export default (() => Body) satisfies QuartzComponentConstructor
