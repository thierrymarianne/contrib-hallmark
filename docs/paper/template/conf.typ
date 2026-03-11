#let conf(
  title: none,
  subtitle: none,
  author: none,
  date: datetime.today().display("[month repr:long] [day], [year]"),
  abstract: none,
  body,
) = {
  set document(title: title, author: author)

  set page(
    paper: "a4",
    margin: (top: 3cm, bottom: 3cm, left: 2.5cm, right: 2.5cm),
    header: context {
      if counter(page).get().first() > 1 [
        #set text(size: 9pt, fill: luma(120))
        #title
        #h(1fr)
        #author
      ]
    },
    footer: context {
      set text(size: 9pt, fill: luma(120))
      h(1fr)
      counter(page).display("1 / 1", both: true)
      h(1fr)
    },
  )

  set text(font: "New Computer Modern", size: 11pt, lang: "en")
  set par(justify: true, leading: 0.8em)
  set heading(numbering: "1.1")

  show heading.where(level: 1): it => {
    v(1.2em)
    set text(size: 16pt, weight: "bold")
    block(it)
    v(0.6em)
  }

  show heading.where(level: 2): it => {
    v(0.8em)
    set text(size: 13pt, weight: "bold")
    block(it)
    v(0.4em)
  }

  v(4cm)
  align(center)[
    #text(size: 24pt, weight: "bold")[#title]
    #if subtitle != none {
      v(0.5em)
      text(size: 14pt, fill: luma(80))[#subtitle]
    }
    #v(2cm)
    #text(size: 12pt)[#author]
    #v(0.5em)
    #text(size: 11pt, fill: luma(100))[#date]
  ]

  if abstract != none {
    v(2cm)
    align(center)[
      #block(width: 80%)[
        #par(justify: true)[
          #text(weight: "bold")[Abstract. ]
          #abstract
        ]
      ]
    ]
  }

  pagebreak()

  outline(indent: 1.5em, depth: 3)
  pagebreak()

  body
}
