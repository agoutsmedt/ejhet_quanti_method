# Introduction

In the last decade, the number of history of economics papers employing
quantitative methods has increased [see e.g.,
@goutsmedtQuantitative2023 special issue]. Several essays have adopted
a reflexive stance, examining the implications of using quantitative
methods in the history of economics [@cherrierQuantitative2018;
@edwardsQuantitative2018]. These contributions provided broad
discussions on the use of such methods. However, given the virtually
unlimited variety of quantitative approaches potentially relevant to
historians of economics---and the wide array of research questions they
can address---these reflections often remain at an abstract level and
offer little practical guidance. As a result, they tend to provide
useful broad overviews, but without clearly articulating what
quantification entails in practice, and how quantitative methods can be
both meaningful and challenging to integrate into research specific to
the history and philosophy of economics.

Our contribution sits between a historical study that uses quantitative
methods to answer a specific question and a general methodological
discussion of those methods. From the collection of data to the
interpretation of results, we illustrate concretely how these methods
are useful and examine, in practice, the methodological choices they
entail. We present a step-by-step application of specific quantitative
methods to a broad topic: the history of rationality in the twentieth
century---using this case to illuminate, in practice, what choices
quantitative analysis involves.

We focus our discussion on unsupervised methods. Unsupervised methods
are machine-learning techniques in which algorithms identify patterns
from unlabelled data, as opposed to supervised learning methods that
learn patterns from labelled data to make inferences. The goal of
unsupervised methods is not necessarily to provide a "measure"
[@grimmerText2022]---though they can be adapted to do so---but to
organise in categories large corpora and enable accelerated and "distant
reading" [@morettiDistant2013; @guldiDangerous2023]. They are well
suited to historical inquiry because their unsupervised nature reduces
the risk of presentism: rather than imposing present-day categories on
the past, unsupervised algorithms uncover patterns directly from the
data. When time is explicitly incorporated, researchers can map the
discipline at different points of time, to identify the emergence and
decline of subjects and concepts, and to assess the influence of
specific economists or ideas.

Our article draws on two types of data, texts and citations. The
analysis of textual corpora offers a direct window into the semantic
content of debates, while citation data provides a means of tracing
intellectual connections and channels of influence within the
discipline. We show how a large corpus of documents can be classified
based on the information contained in textual and citation data---what
we call "*semantic clusters*" and "*bibliometric communities*."[^1]
Combining these two methods allows us both to illustrate concretely the
use of two common approaches for the history of economics. This
combination is also justified by what we regard as a crucial principle
of quantitative analysis in history of economics in particular, and more
broadly in the history of science: the triangulation of different
sources of data and the validation of results through the comparison of
findings obtained from distinct methods.

Above all, our discussion aims to illustrate a core principle for
historical inquiry with such unsupervised quantitative methods. They
require continuous back-and-forth between aggregate quantitative
results, complementary indicators used for interpretation, and
preliminary knowledge and close reading of primary and secondary
sources. These methods function not only as a form of corroboration but
also as "discovery methods" [@grimmerText2022]: they facilitate the
exploration of large datasets to reveal historical patterns. They often
confirm, and sometimes complement, established findings. They can also
reveal pitfalls and blind spots in existing research.

The concept of "rationality" is an effective focus for this concrete
demonstration. First, many historians of economics engage with it in one
way or another, which makes the exercise relevant for a broad audience.
Second, because the concept is broad and pervasive in economics,
applying quantitative methods to a very large corpus is particularly
informative.[^2] We use a corpus of around 290 000 articles in economics
between 1900 and 2009 to show how these methods can handle long time
horizons. Third, the multiple meanings attached to "rationality" and its
uses applied to various subjects show how textual methods, coupled with
bibliometrics, can help capture this semantic plurality.

In what follows, we concentrate on what such a quantitative analysis
requires in practice. We highlight what kinds of questions and
challenges arise at each stage of the research process. This focus lets
us highlight (a) the crucial issue of selecting sources and building
data; (b) how even simple quantitative assessments can be informative;
(c) the challenges and subjective choices involved in building and
adapting tools; and (d) why interpreting results demands careful
attention to various indicators and close knowledge of both the corpus
and its historical context. By tracing, step by step, how we assemble
and analyze our corpus, we aim to provide a practical example and a
reflection on broader methodological issues faced by historians of
economics in quantitative inquiries. The analysis of the results relies
on the use of an interactive application that we have built for this
article.[^3]

# **From sources to corpus**

## From sources to data {#sec-sources_data}

Discussions on quantitative methods often focus on the varieties of
existing methods. In practice, however, implementing a method and
interpreting its results come last. A great deal of effort goes into
collecting, cleaning, and structuring data, much of which remains
invisible in published work. Sources rarely arrive as ready-to-use
datasets; they must be transformed from somewhat raw materials into
usable corpora. In short, the quantitative historian is often a data
wrangler as much as a data analyst.

Bibliometric databases are a convenient way to access corpora of
economic texts: they record relatively well-structured data, gathering
key features of scientific output---authors, journals, affiliations,
*etc*. Some of these databases, such as those provided by *Web of
Science, OpenAlex,* or *Scopus,* record citation data, which enables
tracing intellectual influence through references and mapping scholarly
contributions over time.

Regarding data availability, each database has its own strengths and
weaknesses. While at a very general level Web of Science, OpenAlex, or
Scopus have similar coverage [@martin-martinGoogleScholarMicrosoft2021;
@culbertReference2025], some studies might suffer from choosing a less
appropriate database regarding the research questions. For instance,
Scopus has a lower coverage of the "top five" economics journals before
the 1990s and, while being openaccess, OpenAlex has been less curated
than the products of for-profit publishers. Whatever the provider, less
central or now-defunct journals are more likely to have incomplete or
discontinuous digital coverage, impeding their inclusion for historical
analyses. Additionally, as these databases are oriented toward
English-speaking contributions, they may be inadequate for a research
project targeting other languages.[^4] More generally, citation
practices have only standardised progressively in the postwar period.
Consequently, citation data are most of the time relatively poor before
the 1960s. Last, although they provide useful metadata and citation
information, these databases generally lack full text, which is subject
to copyright and therefore, a large and representative corpus of
economics articles cannot be obtained from a single publisher.

Even when citations and full texts are available, the quality of
information that can be reliably encoded remains limited. Citation data
are difficult to structure, because both the very notion of what
constitutes a reference and the conventions governing its recording have
changed over time---for instance, from references embedded in footnotes
to the development of standardized bibliographies and the author--date
system [@graftonFootnote1999]. Full texts face similar limitations:
mathematical expressions and empirical material, such as tables, are
often poorly captured by providers and difficult to encode properly.
These shortcomings restrict what can be studied by quantitative tools.

In short, the availability and quality of data determine what can be
asked and so answered. The scarcity and structure of data affect every
stage of inquiry, from the choice of research questions to the
interpretations of quantitative results. Scholars are not condemned to
rely on existing databases and may build handmade textual and citation
datasets from scratch. However, such tasks remain time-consuming beyond
small-scale study. More commonly, it is often necessary to combine
information from different databases to fulfill a specific goal. For
example, a medium-scale study of the publications of the European
Economic Review [@goutsmedtIndependent2023]---few thousands
documents---required to combine three heterogenous databases: Econlit
(for JEL codes classification) Web of Science, and Scopus (due to
incomplete coverage of the EER in Web of Science).

For our study of rationality, the first step was to identify the best
sources. For citation data, the Web of Science (WoS) provides areliable
and consistent coverage for our period and has been widely used in the
history of economics
[@culbertReference2025;@martin-martinGoogle2021;@claveauMacrodynamics2016]
. As for full text, we relied on three providers. First, JSTOR's
full-text collection offers good-quality scans of most leading economics
journals [@jstorText2025]. Second, we used Scopus to identify
peer-reviewed economics journals not included in JSTOR and to compile a
complementary list of articles; for these, we retrieved full texts first
through the Elsevier Full-Text API, when available.[^5] Third, remaining
full texts were obtained through the ISTEX project
[@istexInfrastructure2025], which provides access to a substantial
corpus of documents for researchers affiliated with French
universities.[^6] We obtain a first meta-corpus of 290 000 economics
articles that will be later filtered to focus on "rationality".

The @fig-distribution shows the distribution of this meta-corpus across
the years and languages. Our corpus disproportionately represents
Anglo-Saxon journals, which happen to be the most systematically
digitized and preserved. This skew is problematic on two fronts. First,
it risks marginalizing research traditions poorly represented in
English-language articles. Second, it introduces a form of presentism:
the retrospective accessibility of these journals' data today should not
be conflated with their historical centrality, nor should it imply that
journal articles constituted the dominant medium for the circulation of
scholarly ideas. Their prominence within the meta-corpus reflects less
their past influence than their greater capacity, through resources and
institutional support, to maintain comprehensive digital archives.
Conversely, the materials missing "are unlikely to be missing at random"
[@stoltzMapping2024, 11].[^7]

Once access to full text is secured, another crucial step is to
transform them into a usable database. While WoS citations are already
delivered in a relatively structured form, full texts require
substantial processing. In most cases, data are not given but result
from a process that involves cleaning, categorizing, and selectively
removing or reformatting information from raw sources in order to
produce a dataset suitable for computational analysis. This challenge is
particularly true in the history of science and ideas, and more
specifically in the history of economics, where the primary sources
often are the texts themselves. These texts contain layers of content,
such as section headings, footnotes, or bibliographic references.

This data wrangling is not a tedious prelude to "real" historical
analysis. Manipulating, cleaning, and structuring raw sources is a
fundamental and often generative stage of research. As
@lemercierQuantitative2019[62] reminds us, collecting and
categorizing sources is also "a moment to reflect on the sources and the
purpose of the research." Direct engagement with raw data can prompt the
reevaluation of initial hypotheses and the emergence of new questions.
In our case, preparing full‐text documents raises choices about what
counts as a relevant economic text. Should we include book reviews,
working papers, or conference proceedings? How should we define an
"economics journal"---restrict it to core outlets or extend it to
interdisciplinary venues where economics appears regularly? Even within
a single article, boundaries are ambiguous: should abstracts, footnotes,
or appendices be analyzed or excluded? Each decision may carry
historiographical implications. It shapes the corpus and, ultimately,
the history of rationality our methods can reveal. There are rarely
definitive and uncontestable choices, but rather a series of trade-offs
that should be made explicit and required to engage with some of the
material available.[^8]

In light of this article's purpose, we operated a series of choices in
extracting textual data from the full-text materials provided by JSTOR,
Elsevier, and ISTEX. Our first choice was to restrict the analysis to
English-language articles, since cross-language comparisons involve
additional challenges, which would go far beyond the scope of this
article.[^9] We also restrain our analysis to research articles and
filter out book reviews, comments, editorial reports or obituaries.[^10]
While such materials can illuminate how rationality was debated, they
are not primary sites for articulating new ideas within the discipline.
Moreover, textual data are by nature voluminous, and filtering improves
tractability for large-scale computation. At the document level, we
focused on the body text and removed (as far as possible) peripheral
elements such as acknowledgements, references, or appendices. We also
focus on natural-language text and remove other information that is
poorly OCR-processed and often unusable, such as mathematical formulas
and data tables.

To illustrate how corpus delineation and cleaning constitute an
iterative process, it was only after an initial round of exploratory
analysis that we noticed the absence of important economics journals for
our purpose in JSTOR. While preliminary results clearly indicated that
the rise of behavioral economics had impacted how economists discussed
rationality, our domain expertise suggested that certain journals like
the *Journal of Economic Behavior & Organization* or the *Journal of
Behavioral Economics*---later to be the *Journal of Socio-Economics* and
then the *Journal of Behavioral and Experimental Economics*---were
missing precisely where they should have figured prominently. This
prompted us to further explore potential biases in JSTOR and to augment
our corpus with new full texts extracted from Elsevier and the ISTEX
project. Exploring raw sources is thus an important step that requires
to already engage with both collected materials and the existing
literature.

The use of several databases also raised specific issues. Here, our goal
was to combine our textual data (from the three providers mentioned
above) with citation data from WoS. Achieving this required linking
documents across datasets, yet WoS does not provide DOIs, which would
otherwise serve as convenient unique identifiers. It therefore fell to
us to develop matching procedures to determine whether an article
retrieved from JSTOR or Scopus corresponded to the same article indexed
in WoS. However, matching based solely on the title is unreliable. For
example, the title *"Inflation and Unemployment"* may refer either to
James Tobin's [-@tobinInflation1972] AEA presidential lecture or to
Milton Friedman's [-@friedman1977] Nobel lecture. Consequently, we had
to supplement title information with additional metadata, including the
journal name---which required standardizing journal titles across
databases---as well as the publication year, volume, issue, and page
range. Differences in journal coverage and in data storage practices
(particularly title formatting) mean that it is generally impossible to
achieve a complete match between databases. In our case, approximately
one-quarter of the full-text documents after 1945 could not be matched
to WoS records, which prevents us from analyzing their citation
data.[^11]

## From data to corpus {#sec-data_corpus}

In parallel with the transformation of sources into data, we also needed
to establish the boundaries of our corpus, by selecting materials either
*ex ante*, when choosing which sources to include, or *ex post*, when
filtering the collected data. In the context of our project on the
history of rationality in economics, we had to determine what qualifies
as "economics," and second to identify which documents or parts of
documents can be considered "texts" about rationality.

The first challenge was thus to define the extent of our corpus a
priori, i.e. to delineate economics as an object of study. Some research
objects are relatively easier to delineate, and the transition from a
database to a well-defined corpus is therefore straightforward. For
example, writing the history of a particular journal
[@edwardsFifty2020; @charlesRevue2025] or of one or several
individuals [@trucDisciplinary2025; @andradaUnderstanding2017;
@fontanaFragmentation2023] entails comparatively definitional or
boundary challenges. While some large-scale studies focus on the
discipline as a whole [@claveauMacrodynamics2016; @ambrosinoWhat2018;
@bacciniExploring2025], such work still requires an operational
definition of what are documents in "economics." This definitional issue
becomes even more pronounced when the object of study is a specific
"field" or "research specialty" [@morrisMapping2008;
@lyutovMachine2021; ] .

Non-quantitative historical approaches often address large objects by
focusing on clearly identifiable cases or canonical contributions,
allowing the scope of inquiry to remain flexible and progressively
defined. For instance, a historical inquiry on rational expectations may
take @muthRational1961 as a starting point, or focus on the reactions
to Lucas' [-@lucasExpectations1972] model. Quantitative approaches, by
contrast, require the explicit delineation of a corpus from the outset,
which entails making operational choices about inclusion criteria. How
should a corpus on rational expectations be constructed? Which journals
should be included? Should one restrict attention to articles explicitly
mentioning "rational expectations," or also consider related
formulations such as "model-consistent expectations"? Defining the
relevant historical materials therefore involves adopting explicit
conventions to approximate the object under study
[@desrosieresPolitics2011]. The act of delimiting a corpus is a
convention and such act must be assessed instrumentally, not as a
definitive delineation, but as an operational hypothesis tailored to a
specific research question or even an act of "drawing impossible
boundaries" [@lietzDrawing2020; @zittBibliometric2019].

Many "proxies" have been used in the history and philosophy of economics
to define disciplines and sub-disciplines. For instance,
[@fontanaFragmentation2023] restrict their economics corpus to
allegedly most influential economics journals, the "Blue Ribbon Eight";
[@goutsmedtIndependent2023] used the JEL codes to select macroeconomic
documents; while [@trucForty2022] and [@jullienHistory2024] relied
respectively on citations data and institutional affiliations to
identify the boundaries of behavioral economics. However, such
approximations have implications for the object under study. Both JEL
codes and journal classifications---like JSTOR or Scopus
classifications---structure a corpus in ways that reflect their own
histories, and researchers must consider how these classifications shape
the boundaries of their material. For example, while the JEL codes for
neuroeconomics emerged around the same time as the first publications in
the field, the JEL codes for behavioral economics appeared more than two
decades after the earliest contributions [@trucNeuroeconomics2023]. A
thorough knowledge of the history of the object studied is thus crucial
for evaluating the adequacy and representativeness of the resulting
corpus.

In our case, we define *economic* documents by building the corpus from
*peer-review* journals. This convention has both advantages and
limitations. On the one hand, it provides a clear and reproducible
criterion, relying on a predetermined set of journals, rather than
requiring case-by-case decisions about whether individual documents
qualify as "economics". Journals also constitute a central institutional
marker of a discipline, alongside training programs and professional
associations. On the other hand, this choice excludes other publication
outlets, such as books and working papers.[^12] In addition, it only
partially captures interdisciplinarity, missing interdisciplinary
journals or economists publishing in other disciplinary journals.
Finally, this choice also entails boundary decisions regarding which
journals to include, particularly for those at the margins of
"economics", due to their ambiguous editorial standards. We eventually
settled on a carefully curated list of 329 journals identified as
economics journals in JSTOR and Scopus, but excluding journals that are
not entirely academic, insufficiently focused on economics, or only
founded within the last twenty years.[^13] We were able to retrieve
289538 articles published in these journals from 1900 to 2009. These
articles form what we call our "meta-corpus".

The second challenge was to restrain our corpus to documents engaging
with the issue of rationality. One of the most straightforward proxies
are keywords [@trucNeuroeconomics2023]. Based on a predefined list of
target terms (called a "dictionary"), this approach restricts a corpus
to documents that mention these terms with at least a given frequency.
In addition to its relative simplicity, it works well for specific and
unambiguous terms, like "stagflation" [@goutsmedtStagflation2021] or
"Agent-Based Models" [@bacciniDoes2025]. But this approach may exhibit
several limitations in other cases. Indeed, it focuses on identifying
instances of a term rather than the concept as a whole. Just think about
the various ways rationality could be discussed in the history of
economics: beyond the term "rationality", economists employ various
expressions that refer to close ideas such as "maximising profits",
"expected utility", the "*homo oeconomicus"*, or the "transitivity and
completeness of preferences".

Going beyond searching for occurrences of "rationality" and "rational,"
we could have constructed an extensive dictionary of terms associated
with the concept of rationality. It remains difficult to prevent the
dictionary-building process from introducing biases---for instance, by
omitting concepts that are historically relevant but salient only during
specific periods (such as "hedonism"), or by creating a disproportionate
dictionary, with many terms related, for instance, to decision theory
but few pertaining to macroeconomics or public economics. Consequently,
using a list of words constrains the potential for discovery: by setting
the boundaries of the dictionary in advance, researchers may
unintentionally exclude terms or themes of which they were unaware, and
thus remain unaware of them throughout the analysis
[@huistraPhrasing2016; @underwoodDistant2019, chapter 1].

To overcome this issue, we use a Large Language Model (LLM) to identify
documents---and in particular specific sentences within documents---that
deal with rationality in our corpus of economic articles.[^14] LLMs are
trained on extremely large collections of text to learn patterns in
language. The type of models we use, i.e. bidirectional encoder models
such as BERT, learns to predict missing words in a sentence or to
determine whether two sentences follow each other. Through this
training, the model learns billions of internal parameters that capture
regularities in vocabulary, grammar, and meaning. When we input text
into such a model, it represents sentences into vectors that summarize
their context and meaning. The relative position of each vector in this
space reflects semantic proximity: standard distance metrics---such as
cosine similarity---can then be used to compare, rank, or hierarchically
cluster sentences by meaning.[^15] This enables us to compare sentences
not by the exact words they use but by their underlying meaning. For
example, the same term---such as "model"---may carry different meanings
depending on the surrounding context (*fashion model* vs *scientific
model)* and a LLM can detect these variations. By converting words and
sentences into vectors that reflect their semantic usage, LLMs make it
possible to treat ideas and conceptual shifts as measurable objects,
thereby opening new possibilities for the quantitative study of economic
thought.

We rely on Sentence-BERT [@reimersSentenceBERT2019], an LLM designed
specifically to produce sentence embeddings, that is, numerical vectors
that represent the meaning of a sentence. The model assigns one vector
to each sentence, which allows for straightforward semantic comparison:
sentences that express similar ideas end up with vectors that are
mathematically close to each other. Using Sentence-BERT, we vectorized
more than 61 million sentences published between 1900 and 2009 from our
meta-corpus. Starting from a set of *sentences A* including
"rationality" and "rational", we can compute their centroid, that is the
vector obtained by averaging the embeddings of *A*. We call such a
centroid vector a "representative vector", as it encapsulates the
semantic meaning of rational and rationality in our meta-corpus. Then,
we could retrieve a set of *sentences B* that are the most similar to
this centroid. Thus, from a set of *sentences A* explicitly mentioning
the word "rationality," we retrieve a set of *sentences B*---which may
never mention the terms but likely discusses a related idea such as
profit-maximization [see @ashIdeas2026 for a similar use].

Computing a single representative vector over 110 years raises serious
historical issues, though. Because our project is historical, we must
account for how LLMs handle temporally situated language. LLMs are
trained on billions of texts, the majority of which are recent, and
therefore reflect a presentist, numerical view of language.[^16] For
example, current models struggle to reproduce earlier writing styles and
cannot reliably infer the publication date of a text
[@underwoodCan2025]. Sentence-BERT is subject to the same limitations,
and the sentence embeddings it produces inevitably inherit this bias.
Besides, as illustrated by @fig-distribution, our corpus is
exponentially distributed over time, with most sentences drawn from
recent articles and the centroid of our *sentences A* would therefore
itself be skewed toward recent language. Consequently, the sentences
retrieved in set *B*, those closest to the centroid of *A*, would
predominantly come from recent periods. In other words, our results
would reflect a modern understanding of rationality, at the expense of
earlier conceptions of the concept.

To mitigate this presentist bias, we adapted the way sentence similarity
is computed across time (see @fig-rv-method-diagram for a visual
representation of our approach). Instead of comparing a sentence from,
say, 1910 directly to a single representative vector constructed from
all sentences in the corpus containing "rationality" or "rational," we
construct time-specific representative vectors. For each year, we
compute a moving-centroid embedding using a symmetric five-year window,
based on all the sentences containing "rationality" or "rational".
Concretely, for the year 1910, we averaged the vectors of all sentences
containing "rationality" or "rational" from 1905 to 1915.[^17]

This procedure yields a period-specific reference vector that reflects
how these terms were used at that particular moment in time.[^18] A
sentence from 1910 is therefore evaluated not against a general, and
likely contemporary, meaning of rationality, but against its
historically situated usage. We call these centroids the "representative
vectors." They should be interpreted as operational summaries of the
semantic contexts in which "rationality" appears within a given
symmetric five-year window, rather than as fixed theoretical definitions
of the concept. While the representative vectors are not associated with
any real sentences, it is close in the vector space from real sentences.
@tbl-illustrative_sentences reports the 5 sentences closest to the
representative vector, ranked by cosine similarity for the years 1910,
1950 and 2000.

Finally, for each year, we select from all the sentences from our
meta-corpus the 1% of sentences whose embeddings are closest to the
corresponding representative vector.[^19] This yields a
"sentences-corpus" of 499 157 sentences, which is then used for
subsequent textual analysis to identify *semantic clusters* that group
similar sentences together.

We also used our representative vectors to extract from our meta-corpus
the documents that are closest to the corresponding representative
vector. Because each document consists of a set of sentences, we can
also give a vectorial representation to the document by computing the
centroid of its sentence embeddings. Thus, we select the 10% of articles
published after 1960 whose centroid are closest to the corresponding
representative vector. @tbl-illustrative_documents displays the five
closest documents for years 1910, 1950 and 2000 where document vectors
are computed as the centroid of all sentence vectors within the
document. This "articles-corpus", composed of 25 916 articles, is then
used in the bibliometric analysis to identify *bibliographic
communities* from 1960 onwards.[^20]

In the appendix, @fig-method-schema-general summarises this whole
process of building our two corpora from our different meta-corpus and
@fig-rv-method-diagram summarises the construction of the
representative vectors.

# **Exploring the corpus** 

# Simple exploration

Before returning to our specific corpora on rationality and diving into
more advanced LLM-based analyses, we first step back and examine simpler
quantitative methods applied to our broader meta-corpus. Indeed,
quantitative approaches come in many forms and levels of complexity.
Quantification does not need to be sophisticated to be useful. Simple
indicators may not always provide the clearest answers to research
questions, but they play an important exploratory role: helping
researchers refine their questions, identify anomalies, or detect
unexpected patterns.

For textual data, term frequency, that is counting how often particular
words or expressions appear, is a straightforward indicator. This metric
has been used repeatedly in the literature, especially to track the
emergence or decline of fields within economics. In well-delimited
domains, term frequency can serve as a reliable proxy for intellectual
dynamics. For instance, @trucNeuroeconomics2023 shows that counting
occurrences of highly specific neuroeconomics terms in economics
journals---such as "striatum" or "prefrontal"---closely approximates
more advanced quantitative measures, and thus provides a simple but
meaningful signal of activity in the field.

@fig-relative-frequency shows the relative frequency (with respect to
the total number of words published each year) of "rational" and
"rationality" in our corpus. The figure reveals a steady postwar
increase of the use of both terms, likely reflecting the progressive
consolidation of rational choice theory in economics. We observe a
marked surge after the 1970s, with a pronounced peak for "rational" in
the 1980s, and a smaller peak for "rationality" in the 1990s. The rise
of "rational expectations" in macroeconomics and the emergence of
behavioral economics following the publication of @kahnemanProspect1979
likely contributed to this pattern. Of course, one can only speculate
about the precise drivers of these trends from such simple metrics.

While our usage of a LLM will shed light on the context surrounding this
upward movement, such context can also be approximated with simple
measures. Co-occurrence analysis helps recover the different
intellectual settings in which rationality is invoked.
@fig-co-occurence reports, by decade, the five words most frequently
adjacent to "rational" or "rationality," showing how these associations
shift over time. Before the 1930s, the picture was heterogeneous. The
notion was tied to the marginalist idea of "calculation," but it
referred not only to individual behavior but also to "systems" or
"organizations." The discussion was explicitly methodological, as
indicated by the prominence of terms such as "method," "explanation,"
"law," and "foundation." From the 1940s onward, the rise of choice
theory places rationality at the center of economic modeling as a device
for describing and formalizing behavior. This is mostly visible with the
rise of multiple common bi-grams (i.e., combination of two words) that
remain stable from the 1930s through the 1980s such as "economic
rationality", "rational choice", "rational behavior". By the 1970s---and
especially the 1980s---the framework was both extended and contested.
First, the most common bi-gram by far becomes "rational expectations"
signalling the emergence of a new predominant concept extending
rationality. In the 1980s, "rational expectations" appeared 15 more
times than the other most common bi-grams. Second, while the concept
"bounded rationality" was developed by Herbert Simon initially in the
1950s, the concept only became prevalent during the 1990s with the
bi-gram becoming the fourth most common one.

Beyond textual data, citation data also constitute a useful source of
information for corpus exploration. The evolution of an idea depends not
only on how it is formulated by its authors, but also on how it is
appropriated, and reinterpreted by readers. A substantial literature in
citation theory examines how citations function as a scientific practice
and how they should be interpreted [see @tahamtanCore2018 for a
litterature review on the issue]. Citations may reflect a wide range of
motivations---from a genuine desire to acknowledge intellectual debt to
more strategic uses aimed at persuading readers or satisfying referees.
Nevertheless, citations at the very least signal a relationship that can
help trace the lineage and diffusion of ideas, even when the reasons
behind the citation are not purely intellectual. Beyond tracing
diffusion, highly cited papers tend to be more visible and attract
greater engagement---a dynamic that reflects the well-known Matthew
effect [@mertonMatthew1968]. Recent work also shows that citations
influence reading behavior and perceptions of quality: highly cited
papers are more likely to be read thoroughly and treated as significant
intellectual contributions [@teixeiraMatthew2021; @teplitskiyHow2022;
@eikaStarstruck2022].

Historians routinely discuss scientific influence and recognition using
proxies such as major grants, prizes, and honors. For example, Sent's
[-@sent_behavioral_2004] narrative of the transition from the
dominance of rational choice, through the limited success of "old"
behavioral economics (with contributions by, e.g., Simon and George
Katona), to the emergence of "new" behavioral economics is organized
around such milestones. In this sense, citations serve as a
complementary proxy alongside these traditional indicators. For
instance, although both Simon and Daniel Kahneman received the Nobel
Prize, Kahneman ultimately exerted a broader influence on the
discipline---something that is reflected in citation patterns.

@offerNobel2016 distinguished several citation trajectories among Nobel
laureates in economics: those whose citations peak around the award
before declining; "innovators with staying power"; "still rising"
winners honored before their citation peak; and late winners recognized
long after their peak. @fig-rationality-paper-citations illustrates
these dynamics by plotting citation patterns---both across all Web of
Science (WoS) economics journals and within the top five journals---for
four seminal works critiquing the standard conception of rationality in
economics. @simonBehavioral1955 and
@allaisComportementHommeRationnel1953 represent early critiques of
neoclassical rational choice, while @akerlofMarket1970 and
@kahnemanProspect1979 are foundational contributions to what economists
now refer to as "new" behavioral economics. The latter tradition exerted
substantially greater influence than the earlier one, both across all
WoS economics journals and within the top five journals.The contrast
concerns not only the magnitude of influence, but also the timing and
speed of diffusion. Citations to the two "new" behavioral economics
papers increased rapidly and steadily from publication onward, whereas
Simon and Allais reached only modest citation peaks around the time of
their Nobel Prizes---or even later, in the 2000s, amid renewed interest
sparked by "new" behavioral economics. As @offerNobel2016 argue, many
laureates benefit from a "Nobel premium," a modest increase in citations
following the award. Simon and Allais fit this pattern. Kahneman and
Tversky, however, constitute an exceptional case: after the Nobel Prize,
their previously declining citation trajectory reversed and rose sharply
throughout the period under study.

## More advanced exploration

Citation counts are a blunt tool and cannot answer many questions of
interest to historians of economics: Who cites these works? Are they
cited together? In what intellectual contexts do these citations occur?
Moreover, focusing on a small set of references implies a degree of
arbitrariness into the analysis. Likewise, simply counting the words
that appear next to "rationality" tells us little about whether these
words and expressions are used jointly within the same argument or
whether they belong to distinct topics and contexts that mobilize the
concept differently. It also overlooks the much broader vocabulary
related to rationality (e.g., profit maximization, expected utility,
social choice).

Most recent quantitative studies in the history of economics rely on
what can be grouped under the label of "unsupervised methods." These
approaches apply algorithms to a corpus---whether textual or citation
data---to generate classifications and assign categories that are not
predetermined by the researcher but that emerge from statistical
patterns in the data itself, which gives the approach its "unsupervised"
character.[^21] Assigning such categories imposes a form of internal
organization on large and otherwise unwieldy bodies of material,
enabling an accelerated or "distant reading" [@morettiDistant2013].
The typical output of these methods is a map of a discipline or research
area, showing how different entities---topics, articles,
authors---relate to one another.

In contrast to unsupervised methods, supervised methods aim to estimate
predefined relationships or reproduce categories specified in advance.
Supervised methods---such as regression models or classification
algorithms---require researchers to formulate hypotheses, define
variables, or establish categories prior to analysis
[@doAugmented2022]. Unsupervised methods rather seek to detect
patterns, groupings, or structures that emerge from the data
itself.[^22] This "discovery" capacity [@grimmerText2022] is
especially valuable in large-scale and long-run historical analysis,
where the relevant categories may be uncertain, evolving, or difficult
to define in advance. In such contexts, imposing predefined
classifications risks introducing categories that are historically
inadequate or anachronistic. Unsupervised approaches therefore provide a
useful way to identify unexpected regularities, semantic groupings, or
intellectual communities before moving to interpretation.[^23]

In this paper, we use unsupervised methods to analyse both the
articles-corpus and the sentences-corpus. The articles-corpus consists
of the 10% of articles whose embeddings are most similar to the annual
representative vectors. To make sense of this large set of documents, we
employ a method that groups together documents mobilizing similar
understandings of rationality. We use bibliographic coupling, a method
commonly employed in the history of economic thought [see e.g.,
@claveauMacrodynamics2016; @trucForty2022; @bacciniDoes2025]. In a
bibliographic coupling network, documents are represented as nodes, and
links between them are weighted according to the number of references
they share. The more references two articles have in common, the
stronger their connection---and, in network visualisations, the closer
they tend to appear to one another. The underlying premise is that
shared references provide a proxy for intellectual proximity. Such
networks make it possible to identify communities of closely related
documents and to delineate the core-periphery structure of a discipline
or research field.

However, citation practices tend to favor more recent works, which makes
it unhelpful for historians to construct a single citation network
spanning an entire century. Following a method that has proven effective
in the field [@claveauMacrodyanmics2016; @goutsmedtIndependent2023;
@camilottoNavigating2023], we therefore split our corpus into
overlapping eight-year windows,[^24] starting in 1960 (1960--1967;
1961--1968; ... ; 2002--2009), and built a series of 43 separate
networks. Using community-detection algorithms [@traagLouvain2019], we
identify groups of documents that share a substantial fraction of
references and therefore have a similar intellectual background; we
refer to these groups as "bibliometric communities." The next step is to
identify communities that persist over time. When two communities from
consecutive networks share many of the same nodes (i.e. articles), we
treat them as instances of the same underlying group---an "intertemporal
bibliometric community." In this way, our bibliometric communities bring
together documents from different periods of time but that are likely to
engage with rationality in similar ways, based on their shared citation
patterns. This method allows us both to *zoom in* on specific
communities at a given period and to *zoom out* by reconstructing the
broader picture of a dynamic intellectual field.[^25]

For textual analysis, we use the sentences-corpus that gathers the top
1% of sentences that are most similar to our annual representative
vectors of sentences with "rationality" and "rational" (see above and
@fig-rv-method-diagram). To analyse this corpus, as with bibliographic
coupling, we want a method that groups together our observations (here
the sentences) that employ similar meanings of rationality. We draw on
the literature on semantic change that measures the change of meaning of
words over time [@kutuzovDiachronic2018; @montanelliSurvey2024;
@peritiSystematic2024a] and take inspiration from
@giulianelliAnalysing2020. We therefore cluster the sentence embeddings
using the HDBSCAN algorithm, a widely used unsupervised method for
clustering LLM embeddings.

Again, historical perspective matters. Because the distribution of
identified sentences is strongly present-biased (@fig-distribution),
clustering all sentences at once would risk over-representing recent
periods. We therefore perform clustering separately for each decade from
1900 onward (merging the first two decades due to fewer sentences).[^26]
As in our bibliographic approach, we then seek to form larger groups
over time, allowing us to "zoom in" and "zoom out" depending on what we
are searching for. Using the cosine similarity between clusters across
decades, we merge the closest ones into 17 "intertemporal semantic
clusters."[^27]

With both methods, we thus obtain a list of "intertemporal bibliometric
communities" (from 1960 to 2009) and "intertemporal semantic clusters"
(from 1900 to 2009). These allow us to identify subgroups within our
corpus across multiple dimensions: different subfields of economics
(e.g., behavioral economics, macroeconomics), different conceptions of
rationality (e.g., bounded rationality, rational expectations), or even,
more heuristically, different methodological traditions (e.g.,
experimental work, econometrics). Both approaches have clear strengths
and limitations. Some are largely inherited from their respective
sources. In our case, citation data cannot be meaningfully exploited
before the 1960s, while our OCR full texts handle formulas and tables
poorly, making economic models---an essential component of our
story---less visible in the semantic analysis.

Ideally, relying on *both* methods serves complementary purposes. First,
comparing the results of different unsupervised computational
approaches---such as LLM-based embeddings and bibliometric
analysis---acts as a form of robustness check. The systematic comparison
of sources and methods is a long-standing principle in historical
research, allowing scholars to triangulate information rather than
depend on a single perspective. Second, the two methods illuminate
different aspects of intellectual history. Full texts reveal the
meanings, contexts, and semantic nuances of rationality as economists
used the concept in their writing, independently of their institutional
proximity or citation habits. Citation data, by contrast, highlight
patterns of intellectual influence and diffusion: who cites whom, how
ideas travel across fields, and where intellectual boundaries lie. It
conveys sometimes a more sociological dimension: scholars tend to cite
the work of people publishing in similar journals, going to similar
conferences, etc. The following sub-section illustrates how we interpret
our results, and how the two methods complementarity may be useful.

## Interpreting "Results"

Taken together, the textual and bibliometric approaches allow us to
study both the semantic and thematic contexts of the uses of rationality
in economics and the channels through which these ideas circulated
within the discipline. But how should such a "study" proceed? Unlike
simpler quantitative tools, unsupervised methods do not produce
ready-made results. In our case, they generate statistical
categories---bibliometric communities and semantic clusters---that lack
predefined conceptual "labels." This strategy---reducing a large and
complex corpus to a smaller number of coherent groups---is well
established. Yet the groups themselves are created solely on the basis
of statistical similarities, and their historical or conceptual
significance emerges only through subsequent "exploration"
[@simonsLarge2026] and "validation" [@grimmerText2013]. To make
sense of what brings texts together, we therefore need indicators that
identify shared features and help hierarchise the documents to be read
first**.** At the same time, a good knowledge of the corpus and of the
relevant intellectual debates is indispensable for making sense of the
raw computational results, even once they have been informed by a set of
indicators.

Therefore, whether at the stage of data construction or in the
interpretation of statistical patterns, quantitative methods demand a
continuous dialogue with qualitative interpretation, grounded in a close
reading of the relevant secondary literature. Only through this
iterative back-and-forth can we turn algorithmic groupings into
meaningful historical insights. This is both a weakness and a strength.
On the one hand, the analysis is not immediately transparent, as it
requires the construction of intermediate tools---such as our
interactive application---to guide interpretation. On the other hand, it
is consistent with the practices of historians of economic thought, who
likewise select, prioritise, and read texts in order to make sense of
their corpus.

For the purpose of the exploration and interpretation of our results, we
have built an [online interactive
application]([[https://019adac8-81d4-aa0e-808c-08861c261fd2.share.connect.posit.cloud/]{.underline}](https://019adac8-81d4-aa0e-808c-08861c261fd2.share.connect.posit.cloud/)),
where one finds all the semantic clusters and bibliometric communities,
and their corresponding indicators. Let us take as an example the
semantic cluster "Rationality and its Limits," which gathers close to
20,000 sentences from 1920 to 2009.[^28] How can we get a sense of what
this cluster actually coalesces around? Before any qualitative
interpretation or contextualization with the secondary literature, we
must first produce a series of indicators to characterize the cluster.
Such indicators include:

- The most identifying words of the cluster for each decade, based on
  Term Frequency-Inverse Document Frequency (TF-IDF). While the first
  period of the cluster (the 1920s) deals notably with "rationalisation"
  and "human reason," the 1950s are more directly focused on
  "rationalism," "rationality," and "rational behavior." After the 1970s
  and until 2009, "bounded rationality" emerges as a core concept in
  this cluster.

- The sentences within the semantic cluster that are closest to its
  year-representative vector as well as the closest sentences from the
  cluster's centroid itself for each period. The first category tends to
  highlight how the concept of rationality is discussed, while the
  second category centers more directly on the core semantic content of
  the cluster, often offering clues about the topics and debates that
  animate it in different periods. For instance, in the 1950s, one of
  the sentences closest to the representative vectors is Simon's claim
  that "If man, according to this interpretation, makes decisions and
  choices that have some appearance of rationality, rationality in real
  life must involve something simpler than maximization of utility or
  profit" [@simonTheories1959, 259--260]. As for the closest sentences
  from cluster's centroid, Allan Drazen [@drazenRecent1980, 294]
  warned in the 1980s that "Deciding on the suitable notion or
  definition of rationality is not an easy task," in his survey of the
  disequilibrium-theory literature in macroeconomics.

- The articles with the most sentences in the cluster for each decade.
  Here we find, for example, Terence Hutchison's "Expectation and
  Rational Conduct" [@hutchisonExpectation1937]; Jacob Marschak's
  "Rational Behavior, Uncertain Prospects, and Measurable Utility"
  [@marschakRational1950]; Herbert Simon's 1978 Richard T. Ely Lecture
  at the AEA meetings [@simonRationality1978] and his Nobel lecture
  [@simonRational1979]; as well as Sugden's 1991 *Economic Journal*
  survey on rational choice [@sugdenRational1991]. We also observe
  that many of these articles are published in behavioral-economics
  journals such as the *Journal of Socio-Economics* and the *Journal of
  Economic Behavior and Organization*. From the representative sentences
  and articles, we can also infer recurring authors.

- From the 1950s onward, the most cited references (based on the number
  of citations per article, whether the article has one or ten sentences
  in the cluster). In the 1950s, one of the most important references
  within this cluster is John von Neumann and Oskar Morgenstern's
  *Theory of Games and Economic Behavior* [@vonneumannTheory1944],
  while @kahnemanProspect1979 becomes the most cited reference in the
  2000s.

With all these indicators---and prior to any further qualitative
investigation---we can already identify this semantic cluster as
centrally relevant to our study, since it bears directly on the concept
of rationality itself (hence our label, "Rationality and Its Limits").
Our textual approach is therefore capable of isolating specific uses of
rationality---here, debates concerning the meaning of rationality itself
and the limitations of its application in economics---thereby enabling
us to trace the evolution of these uses over time as well as across
topics and subdisciplines, including game theory, macroeconomics,
behavioral economics, and evolutionary economics.

The bibliometric approach does not allow for such temporal or
cross-subdisciplinary exploration. In our bibliometric communities, no
grouping addresses rationality and its limits in general across multiple
decades. Rather, bibliometric analysis identifies groups of articles
from authors in close academic communities. In relation to the semantic
cluster "Rationality and its Limits", we observe, for instance, the
emergence of the community "Behavioral Economics: Risk & Uncertainty"
community in the 1981-1988 window. As with the semantic clusters, for
each bibliometric community in each temporal window we extract, notably,
the sentences closest to the representative vectors---based on the
articles belonging to the community---as well as the most cited
references and the most identifying words. We also examine how each
community in a given window originates (i.e., whether it derives
primarily from the same or from different communities in preceding
periods) and what it becomes in the following period (i.e., its
subsequent "destiny").

# **Discussion**

Equipped with these groupings and indicators, we can make sense of our
results. How can they help enrich, complete, and refine our
understanding of the various and evolving meanings of rationality in
economics? This paper does not propose an alternative history of the
concept, which would extend far beyond the scope of this methodological
discussion. Rather, we highlight selected findings that corroborate and
strengthen strands of the existing literature, notably by allowing us to
make claims about the prevalence and timing of considerations about
rationality, while also broadening the scope of that literature and
opening avenues for further research.

Throughout much of the period---but especially before the
1940s---sentences captured by our representative vectors refer sometimes
less to the rationality of economic agents than to the rational
character of economists' arguments, understood in terms of coherence or
sound reasoning. This pattern reflects the logic of our semantic
approach: LLMs tend to associate explicit mentions of rationality with
broader discussions of reasoning and coherence, even when the connection
to later, behavior-centered notions of rationality remains indirect. We
retain this ambivalence deliberately since it reveals both historical
semantic change and the interpretative challenges inherent to
large-scale analysis.

Our goal is also to show how we navigate the results and triangulate
indicators to produce coherent historical narratives. While we rely on
the secondary literature, the articles we foreground are those
identified by our indicators as some of the most significant for
understanding the semantic clusters or bibliometric communities.[^29] We
provide two complementary discussions: a macro-level perspective that
highlights broad patterns in the evolution of rationality, and a
micro-level analysis that focuses on the emergence of a specific
topic---behavioral economics.

## Through the Telescope: Broad Patterns on the History of Rationality {#telescope}

When our quantitative inquiry begins in 1900, the concept of rationality
had already gained prominence, in line with the rise of scientific and
abstract reasoning in the late nineteenth century. The scope of rational
behavior was closely tied to debates on the proper domain of economic
analysis [@giocoliModeling2003]. With the marginalists, the economic
agent was increasingly defined by calculative capacity. Jevons, for
instance, portrayed the agent as a "calculating machine" balancing
pleasures and pains, a view later formalized as utility maximization
[@maasMechanical1999].

In our first two decades, semantic cluster "Utility Theory" represents
discussion centred on utility and brings together insights on marginal
utility from, among others, Sidney. J. Chapman, Arthur Pigou, Francis Y.
Edgeworth, and John M. Clark. Cluster "History of Economic Thought &
Philosophy of Economics" also captures discussions about utility:
arguments about utility were framed as interpretations, critiques, or
extensions of classical authors---most notably Mill, Ricardo or Malthus.
Yet, if anything, our results suggest that marginal utility theory
appears mostly under severe criticism in this period, especially from
institutionalist economists such as Thorstein Veblen, Wesley Mitchell,
John Maurice Clark, and Rexford Tugwell.[^30]

The criticism was directed along two main lines. First, as
@giocoliModeling2003[48--50] points out, institutionalist economists
rejected the "unfounded psychological underpinnings of neoclassical
economics" and sought to replace them with sounder foundations [see
also @yonayStruggle2001, 101-106]. They proposed instead to renew the
economic method by drawing on psychology and its emerging "behaviorist"
approach [@rutherfordInstitutional2001, 175--176]. Semantic cluster
"Methodological Discussions" captures a significant share of sentences
from 1900--1920 that articulate such institutionalist critiques.
Institutionalists were energized by new developments in psychology. In
his review of the literature on "Human Behavior and Economics," Mitchell
emphasized the growing interest of economists in psychological matters,
which stemmed from "a somewhat tardy recognition that hedonism is
unsound psychology, and that the economics of both Ricardo and Jevons
originally rested on hedonistic preconceptions" [@mitchellHuman1914,
1]. For economics, the crucial issue was thus to choose "between
providing a sounder psychological basis for our analysis, and holding
that its psychological basis does not concern the economist" (2).[^31]
Such criticism did not falter in the 1920s. In the cluster "Rationality
and its Limits"---centered at the time on "rationalisation" and "human
reason"---@tugwellHuman1922[317] encouraged economists to move beyond
the "rigid classical *homo economicus*" and noted that "psychologists
have already pretty well revolutionized the scientific definition of
human nature."

Second, for institutionalist economists, institutions were indispensable
for understanding economic behavior, and different institutions implied
different behaviors; there was no single, context-independent *homo
oeconomicus*. In the cluster "Methodological Discussions", in his review
of John Bates Clark's contribution, @veblenProfessor1908[159-160]
argued against the "statical scope and character" of marginal-utility
theory, which, in his view, cannot address "questions of genesis,
growth, variation, process." Similarly, in the cluster "Utility Theory",
E. H. @downeyFutility1910[253] claimed that "Marginal-utility
economics has nothing to say of the genesis, growth, or current working
of economic institutions" [see also @rutherfordInstitutionalist2013,
141]. Its "deliverances," he argued, were therefore "futile for the
problem of social betterment," since such "betterment" concerned the
adjustment of institutions to changing circumstances and ideals. In the
early twentieth century, economic behavior, according to
institutionalists, had to be understood through the prism of the
"pecuniary institutions" that shaped it. For instance, in the cluster
"Methodological Discussions", Charles Cooley [@cooleyProgress1915]
underlined that "pecuniary valuation," or economic valuation, is only
possible because of the institutions that make such valuation possible
[see also @rutherfordInstitutionalist2013, 58--59].
@fig-co-occurence shows well the importance of "pecuniary" as a
neighbor to "rational" and "rationality" in the first twenty years of
the twentieth century.

The centrality of institutionalist economists---as well as the
prominence of U.S. journals in our corpus---is visible in the scope of
the semantic clusters in the first periods: sentences related to
rationality, in addition to the clusters already mentioned, were grouped
into themes related to the railway industry, progressive taxation (see
cluster "Legislation, Regulation & Planning"), tariffs and commercial
policy in the United States (see cluster "Price Theory"), or agriculture
(see cluster "Agricultural Economics"). In line with institutionalism,
most of these economists examined these themes through the laws and
rules governing economic activity, focusing on how institutions
structure the behaviour and interests of collective actors rather than
on abstract individual assumptions. Within these clusters, "rationality"
is rarely invoked explicitly, although discussions of the behavior of
"business men" (cluster "Firm Theory & Entrepreneur"), "workmen"
(cluster "Legislation, Regulation & Planning") or "owners of land" and
"farmers" (cluster "Agricultural Economics") were common. Across
successive periods, however, these thematic configurations declined in
prominence, and most intertemporal clusters associated with them
disappeared after the Second World War. Indeed, the period from 1930 to
1959 displays substantial transformations in the structure of debates
concerning rationality.

The most obvious transformations are those described by
@giocoliModeling2003 as "the escape from psychology" and, more
generally, the shift from a "system-of-forces"---"economic processes
generated by market and non-market forces"---to a "system-of-relations,"
in which the aim becomes to establish the existence and properties of
equilibria through the "validation and mutual consistency of given
formal conditions" [@giocoliModeling2003, 4--5]. "Rationality" was
progressively distinguished from "reason" or "intelligence" and recast
as a formal, axiomatic notion---"rigid rules that determine unique
solutions" [@ericksonHow2013; see also @klaesConceptual2005].

While intertemporal semantic cluster "Utility Theory" constituted only a
tiny share of sentences between 1900 and 1919, and was absent in the
1920s, it gains importance in the 1930s to the 1950s (though still
representing less than 5% of all sentences). During this period, the
heart of the debate concerned the measurability of utility and the
opposition between "cardinal" and "ordinal" utility. In the 1930s, the
debate still bore on the psychological dimension of utility measurement.
In 1933, John Hicks and Roy Allen [-@hicksReconsideration1934]
coauthored an article on demand analysis that eliminated marginal
utility by appealing to the concept of the marginal rate of
substitution---the slope of the indifference curve [see
@moscatiMeasuring2019, 98--100]. Already in 1932, Allen had made this
project explicit: by starting from "preferential discrimination," or
individuals' preferences over different bundles of goods, it becomes
unnecessary to "make any assumption about the existence of 'total
utility' or about the measurability of 'utility'; the hedonistic
hypothesis has been rendered superfluous" [@allenFoundations1932,
207].[^32] In other words, "Subjective and psychological concepts have
been discarded from pure economic theory" (ibid.).

Yet this position was not uncontested. Indeed, in these debates, terms
such as "introspection," "satisfaction(s)," and "pleasure" recur
frequently in the cluster during the 1930s and 1940s [see TF-IDF, and,
for instance, @armstrongDeterminateness1939]. But they disappear from
the top identifying words in the 1950s. During this period, debates on
ordinal versus cardinal utility continued---with a renewed defense of
the cardinalist position and ongoing disputes about the very meaning of
"measuring utility" [@moscatiMeasuring2019, chapter 10]---yet these
discussions had largely emancipated themselves from psychological or
behaviorist considerations. These debates are also associated with a new
intertemporal semantic cluster "Decision Theory", distinct from the
cluster "Utility Theory." Appearing in the 1940s and expanding
substantially during the 1950s---to nearly 8% of all sentences---this
cluster centers on the formalization of agents' preferences and choices.
Here, we encounter what would become the standard vocabulary of decision
theory: "individual orderings," "preferences," "decisions,"
"transitive," etc., and @vonneumannTheory1944, @friedmanUtility1948,
and @savageFoundations1954 are the most cited references by the core
articles of the cluster. To complete this panorama, a separate cluster
"Game Theory" emerges in the 1950s, which ultimately comes to represent
nearly 15% of all sentences after 1990.

Transformations in the conception of rationality are also visible in
intertemporal semantic clusters that persist over time while reflecting
profound shifts in the discipline's methodology and the growing
centrality of rational choice theory*.* The cluster "Firm Theory &
Entrepreneur" spans the period from 1900 to 1979 and therefore provides
a useful vantage point from which to trace how changing conceptions of
rationality reshaped the treatment of firms' decisions. In the 1920s,
the cluster emphasizes entrepreneurial decision-making, understood
primarily as prudence facing uncertainty rather than formal
optimization. From the 1940s, this cluster increasingly centers on
"profit maximization." The cluster captures the core of the so-called
"marginalist controversy" [@backhouseFriedmans2009], notably through
Richard Lester's attack on marginal theory and Fritz Machlup's
[-@machlupMarginal1946] response. Machlup defended profit maximization
and, more broadly, marginalist theory itself. He rejected the evidential
value of Lester's questionnaire-based surveys of entrepreneurs, while
Lester replied that "at the heart of economic theory should be an
adequate analysis and understanding of the psychology, policies, and
practices of business management in modern industry"
[@lesterMarginalism1947, 146].[^33] More generally, the marginalist
controversy provided a key intellectual background for Friedman's essay
on positive economics [-@friedmanMethodology1953], in which he
formulated the "as if" principle to justify, among other assumptions,
profit maximization. By the 1950s, the most cited articles within the
cluster "Firm Theory & Entrepreneur" were Machlup's
[-@machlupMarginal1946] and Friedman's [@friedmanUtility1948], both
of which relied heavily on "as if" reasoning, notably to justify, in the
latter, the behavior of agents regarding expected utility.[^34]

Shifts in the discipline's methodology are also captured by the cluster
"Methodological Discussion." While in the 1920s and 1930s economists
still engaged with notions such as "human nature," "passions," or
"prejudices," the postwar period saw the growing prominence of terms
such as "logical implications" and "assumptions," followed, from the
1970s onward, by an increasing focus on "models" and "optimality."

It thus becomes clear that by the 1950s the conception of rationality
had been profoundly transformed, moving in a more formal direction and
largely emancipated from psychology. Another transformation also
deserves emphasis: as rationality was recast in terms of consistent
choice rather than as a psychological portrait of *homo oeconomicus*,
the normative dimension expanded---from individual behavior to questions
of social choice and of "rationalizing" policies [@ericksonHow2013;
@handsNormative2015].

The emergence of this social dimension of rationality is already
observable in the interwar period, well before the Cold War. In the
1930s, the concept of "rationalization"---relatively neglected in the
history of economic thought---was central in the cluster "Rationality
and its Limits." In a literature review on this concept, Robert Brady
[@bradyMeaning1932, 526] remarked that "scarcely any term... has
occasioned more discussion and dispute." The concept referred to "every
technique, program, or plan of organization which promised to promote
(...) the 'efficiency' of individual enterprises, entire industries, or
even the total of economic processes nationally or internationally
considered." Attention to "rationalisation" is also visible in the
cluster "Agricultural Economics", with the rise of "farm management"
aimed at improving farmers' living conditions. It becomes even more
pronounced with the multiplication of debates on economic planning and
the rationalization of policy decisions from the 1940s onward,
particularly in the cluster "Legislation, Regulation & Planning."

As rationality increasingly came to be framed through modern
microeconomics, the concept was extended to collective choice. In the
intertemporal semantic cluster \"Decision Theory", the rational
"decision making" is applied not only to individuals but also to firms
and public policy. Social choice issues emerge in this cluster in the
1970s, notably through debates on the implications of Arrow's
impossibility theorem [-@arrowSocial1951; see e.g.
@igersheimDeath2019].[^35] Arrow's contribution also stimulated the
formation of the cluster "Voting & Public Choice" in the 1960s, where it
appears as the primary reference, alongside works by @downsEconomic1957
and @buchananCalculus1962. This cluster is closely associated with
publications by *Public Choice* [see @cherrierEconomists2017].
Welfare economics and public choice, as well as public finance
[@desmarais-tremblayPublic2023], are also clearly visible in the
bibliometric analysis after 1960. Indeed, one of the major bibliometric
communities of the 1960s "Public Economics: Externalities" with James
Buchanan, Ronald Coase, and Richard Musgrave as central references. The
prominence of public finance increases further in subsequent decades,
with many communities gravitating around "Public Economics:
Externalities", notably one devoted to optimal taxation after 1968;
taken together, these different "Public Economics" communities account
for more than one fifth of the entire network in these periods.

We have seen how the meaning of rationality progressively transformed
and formalized after the 1930s, and how the rationalization of
collective decision-making became central in the postwar period. So far,
however, we have said little about macroeconomics. Macro-oriented issues
constituted a relatively important semantic cluster from the beginning
of our period, in 1900, notably with the intertemporal semantic cluster
"Monetary Policy & Rational Expectations). This cluster grew in
importance in the 1930s, in connection with debates surrounding Keynes's
work, liquidity preference, and unemployment. It is only in the 1970s,
however, that this cluster becomes dominant in our panorama of
rationality. This shift is closely linked to the emergence of the
concept of "rational expectations," which profoundly transformed the way
rationality was discussed in economics. The concept was developed by
@muthRational1961 but only later popularized when Carnegie
colleagues---Robert E. Lucas, Edward C. Prescott, and Thomas J.
Sargent---applied it to macroeconomics [@lucasExpectations1972;
@sargentRational1973]. By the late 1970s, it had circulated beyond
academia into policy circles and the press, and was often described as a
"rational expectations revolution" [@duarteRise2025]. Our methods help
account for this rapid diffusion beyond controversial policy debates
during the stagflation era. First, the results show no significant trace
of rational expectations in the 1960s in either the bibliometric or
textual outputs.[^36] But from the 1970s onward, it occupies a central
place in the literature on rationality, reaching its apogee in the
1980s, when it accounted for nearly 30% of all sentences in the textual
analysis, as well as a comparable share of articles in the bibliometric
analysis, spread across several bibliometric communities
("Macroeconomics: Business Cycles & RE," "International Macroeconomics,"
and "Macroeconomics: Modelling Consequences of RE").

A similar trajectory to macroeconomics can also be observed in finance.
The origins of financial issues can be traced to the semantic cluster
"Capital & Investment Theory," which focused initially on the theory of
investment. Until the 1930s, the issue was framed around the returns of
capital. For instance, the cluster includes the so-called Hayek-Knight
controversy on the conception of capital [@cohenHayek2003]. After the
1940s, decision-making under uncertainty becomes a central theme,
crystallized by works such as George @shackleTheory1942 on investment
under radical uncertainty, which figures among the most representative
articles. One decade later, Jack @hirshleiferTheory1958 inscribed
investment theory within the rising neoclassical conception of
rationality, by formalizing investment decisions as a problem of
intertemporal maximization of consumption*.* In the same vein, the
Modigliani--Miller theorem [@modiglianiCost1958] further consolidated
this shift by grounding firm financial decisions as an arbitrage
problem, opening the path to modern financial economics. Their theorem,
they argued, can be used "as a basis for rational investment
decision-making within the firm" [@modiglianiCost1958, 296]. After the
1960s, the cluster "Capital & Investment Theory" became much more
prominent, accounting for more than 10% of all sentences. In this
period, rationality is increasingly framed in formal decision-theoretic
terms and focused on appropriate investment choices under uncertainty.
Hence, our analysis shows that rationality in finance enters primarily
through corporate finance, rather than through asset-pricing issues such
as market efficiency, where rationality long remains an implicit
assumption, rarely discussed explicitly prior to the emergence of
behavioral finance.

However, from the 1980s onward, modern asset pricing becomes dominant
within the cluster "Capital & Investment Theory" as indicated by the
growing prominence of terms such as "assets," "arbitrage," and "capital
asset pricing". We also observe increasing proximities between the
finance literature and the rational-expectations framework from the
mid-1970s onward. This is visible both in the textual and bibliometric
analysis, in particular with the "Finance: Market Information"
bibliometric community, which emerges in the 1971-1978 window and
focuses increasingly on rational expectations. A central contribution
found in both semantic and bibliometric clusters is
@grossmanImpossibility1980, which draws on Lucas's
imperfect-information framework [@lucasExpectations1972] and combines
rational expectations with noisy signals to question market efficiency.
More generally, rational expectations models---initially developed in a
macroeconomic context---became a central framework for analyzing the
(ir)rational use of information in finance [see
@delceyEfficient2023].

The 1970s and 1980s thus marked a relative dominance of macroeconomics
and finance, with comparatively less weight given to debates on
individual rationality. This situation begins to change gradually from
the 1980s onward. In the 1981-1988 bibliometric network, the community
"Behavioral Economics: Risk & Uncertainty" appears (representing around
5% of the network), capturing the early emergence of behavioral
economics as promoted by Kahneman and Tversky. In the 1990s, the rise of
behavioral economics---together with new approaches in game
theory---fundamentally altered this configuration, leading to more
specialized investigations of individual rationality, which now dominate
and are distributed across multiple bibliometric communities. This
transformation represents not merely a shift in research topics, but a
profound reframing of how economics approaches rationality: from an
assumption embedded in theories and models to an object of direct
investigation at the individual level.

We have sought here to offer a broad panorama of the major
transformations in the concept of "rationality" in economics. This
approach allows us to identify large-scale changes when they become
visible in the data---namely, when particular clusters come to represent
a significant share of sentences (or of the bibliometric networks).
However, historians of economic thought are often concerned with
understanding how such transformations came about: which contributions,
authors, and communities played a decisive role. Addressing these
questions requires a more focused perspective, tracing the evolution of
specific topics and literatures. This is the aim of the next section,
which moves beyond the panoramic view to provide a more detailed
narrative of the rise of behavioral economics outlined above.

## Under the Microscope: Simon's Reception and the Birth of Behavioural Economics

The term "behavioral economics" has a complex history. While it is now
mostly associated with the work of Kahneman and Amos Tversky, George
Katona is often credited as an early adopter of a behavioral approach
[@giladEconomic1984; @hosseiniGeorge2011]. To distinguish among
different strands of behavioral economics, @sent_behavioral_2004
proposed an influential distinction between "old" and "new" behavioral
economics. This distinction separates the heterogeneous and reformist
efforts of Katona, Simon, and others to challenge mainstream economics
from the more homogeneous heuristics-and-biases research program
developed by Kahneman and Tversky. Sent argues that "new" behavioral
economics succeeded in part because it was less radical than earlier
approaches and because it emerged in the 1980s, at a moment when
economic theory faced multiple epistemological challenges, thereby
creating an opportune context for alternative frameworks.

The divergent fates of Simon's bounded rationality and Kahneman and
Tversky's heuristics-and-biases approach thus present a striking puzzle
in the history of economic thought. Both challenged standard assumptions
of rationality under the banner of behavioral economics, and both were
ultimately recognized with Nobel Prizes, yet their patterns of reception
and adoption differed. While our methods cannot identify the precise
epistemological mechanisms behind this divergence, they allow us to
trace and compare the trajectories of reception and influence of these
two approaches, shedding light on how and when they followed different
paths.

Our analysis suggests that Simon's concept of "bounded rationality"
stands as one of the most influential critiques of standard rationality
in economics, particularly in its role in structuring debates about
rationality itself. Simon's work dominated discussions in the 1960s and
1970s, with his seminal articles [@simonBehavioral1955;
@simonTheories1959] and his Nobel lecture [@simonRational1979]
appearing across a wide range of research areas, from social choice
theory to the theory of the firm and price setting. The textual analysis
highlights Simon's conceptual centrality. Semantic cluster "Rationality
& its Limits" undergoes a marked transformation following the rise of
Simon's influence. In the 1950s, the discourse was centered on terms
such as "rational behavior," "rationalization," and "irrationality." By
the 1970s, "bounded rationality" had become one the most prevalent
expression in the cluster, and by the 1990s, references to "boundedly
rational agents" and "procedural rationality" clearly positioned Simon's
concepts at the core of economic discussions, reflecting a delayed but
substantial integration into the discipline.

Moreover, Simon's impact is visible not only in the changing language of
rationality but also in the growing prominence of these debates within
economics. The cluster "Rationality & its Limits" expands from 5.76% of
all sentences in the 1950s to 7.85% in the 1980s, peaking at 9.56% in
the 1990s. This growth signals a significant increase in the attention
devoted to foundational questions of rationality. Citation analysis
corroborates this pattern of late recognition: references to
@simonBehavioral1955 rise gradually after publication, with citation
peaks occurring only in the post-2000s period (see
@fig-rationality-paper-citations).

However, Simon's influence remained limited in two critical respects.
First, the slow diffusion of his framework meant that, by the time it
achieved broad conceptual prominence, it faced direct competition from
"new" behavioral economics, present in semantic clusters "Decision
Theory" and "Decision Under Uncertainty", as well as in "Consumption,
Savings & Intertemporal Choice" and "Game Theory". All of these four
clusters expanded rapidly in the 1980s, with most of them individually
surpassing cluster "Rationality & its Limits" in their share of
sentences. Although these strands incorporated elements of bounded
rationality, they did so primarily through the conceptual tools of "new"
behavioral economics---ranging from prospect theory in the analysis of
risk to experimental paradigms such as the ultimatum game in game theory
[@gualaParadigmatic2008].

Second, Simon\'s conceptual influence, spearheaded by bounded
rationality, never translated into stable research communities. While
his framework shaped how many economists approached rationality, very
few actually developed the research program he initiated.
Bibliometrically, only small, unstable communities formed around
Simon\'s work. In the 1960s and early 1970s, his ideas appeared in
*Public Economic* clusters, operations research circles and behavioral
theories of the firm (*cl_165*) and critique of the standard
profit-maximizing such as socialist enterprise theory (*cl_123*). Simon
was generally associated with other researchers critical of perfect
rationality: @winterSatisficing1971, which applied satisficing to firm
behavior; @cyertCompetition1969 on behavioral theory of the firm; and
@leibensteinAllocative1966 on "X-efficiency," challenging economics\'
focus on allocative efficiency (*cl_179*). Together, Simon, Winter,
Cyert, and Leibenstein formed a diverse organizational theory critique
of how rationality, especially through profit maximization, is employed
in economics. While this collective movement had some momentum, none of
these research had an individual effect on economics structure [see
also @sent_behavioral_2004]. After 1969-1976, these different research
streams coalesced into small short-lived community (*cl_258*) before
fragmenting. References to Simon and critiques of profit maximization
remained scattered, moving through several small communities (e.g.,
*cl_793* on post-keynesian economics, *cl_755* on contract theory,
*cl_773* and *cl_614* on institutionnalist approaches) without ever
achieving the critical mass. While Simon's influence in economics was
conceptually enduring, it remained marginal as a structuring force,
unable to generate coherent, large and stable research communities.

"New" behavioral economics reception reveals a dramatic contrast. Unlike
Simon's trajectory, the heuristics and biases research program of
Kahneman, Tversky, and other "new" behavioral economists generated
multiple stable clusters that formed well-identified and substantial
research communities. A main "Behavioral Economics: Risk & Uncertainty"
cluster emerged in 1981-1988, structured by early adopters of the new
approach. The crystallization of this distinct cluster signaled the
beginning of explosive growth and the spinning off of several autonomous
communities that captured emerging specialized areas of behavioral
economics: pro-social behavior (*Behavioral Economics: Social
Preferences*) and behavioral game theory (*Game Theory: Behavioral*),
intertemporal decision-making and risk (*Behavioral Economics: Risk &
Uncertainty*), and behavioral finance (*Finance: Behavioral Finance*).
In a lot of these cases, behavioral economics clusters come to outgrow
or replace existing clusters (e.g., game theory, decision theory).

By the 2000s, behavioral economics had become the dominant venue for
research on rationality. Three behavioral economics communities
represented approximately 30% of the entire network with many additional
communities structured by behavioral economics research without being
explicitly characterized as such. The scale and speed of acceptance
differed dramatically from Simon's experience. By 1980,
@kahnemanProspect1979 had already surpassed @simonBehavioral1955 in
annual citations (@fig-rationality-paper-citations). By 1985, prospect
theory had already surpassed the lifetime citation peak that Simon's
work would ever reach within economics. By the 2000s, most microeconomic
publications addressing rationality were explicitly connected to the
behavioral economics research program. While bounded and procedural
rationality remained frequently invoked concepts, no subsequent research
community clearly carried Simon's legacy as a stable bibliometric
anchor.

The contrast is stark and raises fundamental questions about
disciplinary reception. Our quantitative study yields two particularly
surprising results regarding the contrasting influence of Kahneman and
Simon. First, the temporal patterns of adoption differ radically. For
the historian @heukelomBehavioral2014, a pivotal moment in the history
of behavioral economics was the explicit creation of research programs
within the Sloan and Russell Sage Foundations between 1984 and 1992,
notably fostering the Kahneman--Thaler collaboration that decisively
transformed the field's trajectory. Our analysis, however, suggests that
a distinctive dynamic was already underway by the early 1980s in the
reception of Kahneman and Tversky's work. Despite the fact that
@kahnemanProspect1979 was the duo's only publication in an economics
journal until 1985---well before the Sloan--Russell Sage programs
formally institutionalized behavioral economics---prospect theory
experienced rapid and sustained citation growth
(@fig-rationality-paper-citations). This align with a general findings
in scientometrics that citations in the first two years after
publication explain more than half of the variation in cumulative
citations [@sternHighRanked2014]. While the institutionnal structures
that came after played an important role in the subsequent reception of
the research program as a whole, it is important to recognize how the
reception of Kahneman and Tversky's differ greatly in the couple of
years after publications. Moreover, as early as the 1978--1985
bibliometric network, we identify an autonomous cluster structured
around their work (cl_391), indicating that the article not only
attracted citations but quickly catalyzed new research strands, in a way
Simon's work never did within economics [@heukelom_sense_2012].

The second surprising finding concerns the relationship between "old"
and "new" behavioral economics. Contrary to narratives of rupture or
forgetting, citations to @simonBehavioral1955 have never been as high
as during the rise of new behavioral economics---a paradoxical pattern
given recurrent claims that the field has neglected its intellectual
roots. @earlPrinciples2022 criticizes this apparent amnesia:

> Neither Kahneman nor Thaler have sought to promote earlier behavioral
economics alongside more recent work. Instead, they give the impression
that behavioral economics started around 1979--1980 with the publication
of Kahneman and Tversky's (1979) article on prospect theory and that
theory's use by Thaler (1980). All in all, this is a very curious state
of affairs: a cynic might suggest that it looks rather as if the earlier
work has been airbrushed from the history of economic thought by the
strategic redefinition of what constitutes behavioral economics. A more
charitable and reflexive view would see the situation as resulting from
insufficient familiarity with the earlier literature
[@earlPrinciples2022, 2]

The rising citations to earlier work by Simon and Allais demonstrate
that, while "new" behavioral economists may not consistently acknowledge
the contributions of "old" behavioral economics, the rapid expansion and
growing scale of the field have nevertheless drawn unprecedented
attention to these earlier works, far exceeding the recognition they
received at the time of their original publication. This pattern admits
at least three interpretations, each carrying distinct implications for
how we understand the evolution of economic thought.

A favorable interpretation holds that "new" behavioral economics has
genuinely revived previously abandoned research directions, moving
toward a reconciliation with earlier strands---a trajectory explicitly
advocated by @sentRationality2008 and more recently by
@earlPrinciples2022. A more critical reading emphasizes intellectual
appropriation, whereby classic references are selectively reframed to
fit the new agenda, renewing interest but through a biased and
presentist lens, as Mongin has argued in the case of Allais
[@monginAllais2019]. A third interpretation suggests that rising
citation counts reflect a growing backlash against the "new" behavioral
program, as defenders of "old" behavioral economics increasingly invoke
Simon and others to challenge the heuristics-and-biases framework.

Our findings tentatively support the second interpretation. The sparse
and weakly structured citation patterns associated with "old" behavioral
economics, combined with the fact that contemporary discussions of
rationality are increasingly framed through the concepts and tools of
"new" behavioral and experimental economics, point toward appropriation
rather than genuine integration. Citations may acknowledge earlier work
without engaging its distinctive methodological commitments or
theoretical ambitions. Simon's influence thus persists primarily as a
symbolic and framing reference, useful for situating debates and
reconstructing intellectual lineages, while his substantive framework
remains only superficially incorporated. Although a definitive
assessment would require closer qualitative analysis of how these
citations function in contemporary texts, our study provides a
quantitative roadmap for future research on the complex and ambivalent
relationship between "old" and "new" behavioral economics.

# **Conclusion**

This article is first and foremost methodological: it aims to
demonstrate, through a concrete application, the usefulness of
quantitative methods for the history of economic thought. Nonetheless,
it does so by breaking new ground in the history and philosophy of
economics. First, the corpus we build---comprising nearly 290,000
full-text economics articles spanning more than a century---is, to our
knowledge, the largest and most comprehensive database ever used to
study economic contributions in English. Second, this article
constitutes the first application of quantitative methods to the study
of "semantic change" within the history of economics, an area that
represents an important and growing strand of the literature on
quantitative text analysis [@montanelliSurvey2024].

Our approach allows us to identify, within this corpus, the sentences
most closely associated with the words "rational" and "rationality" and,
by extension, the articles most likely to engage with rationality in one
way or another. By allowing the algorithms to identify dozens of
semantic clusters and bibliometric communities within short temporal
windows (eight years or a decade), and by then aggregating these
groupings over time and characterizing them through multiple indicators,
we can conduct analyses at different scales. This makes it possible both
to *zoom out*, by examining the overall configuration of clusters across
periods, and to *zoom in*, by focusing on subsets of clusters more
directly concerned with rationality. As shown in the previous section, a
panoramic view that considers all semantic clusters may initially
include groups that appear only loosely connected to
rationality---especially in the early decades. While examining these
clusters can be informative for understanding the broader intellectual
context, the analyst can also foreground more explicitly
rationality-oriented clusters when addressing more targeted research
questions. This flexibility is only possible because the initial corpus
is sufficiently inclusive, reducing the risk of overlooking relevant
developments. More generally, our approach allows the scale of analysis
to be adjusted to the question at hand, rather than imposing it ex ante.

We want to conclude by drawing several general methodological and
historiographic claims from the approaches developed in this article.

First, although quantitative methods in the history and philosophy of
economics have been applied mainly to the postwar---and often
post-1970s---period, our study shows that they can also be used
effectively for earlier periods. Despite problems of text recognition in
JSTOR articles prior to the 1930s, our methods nonetheless provide a
fine-grained depiction of economic debates in the early twentieth
century. In particular, we were able to recover most of the
institutionalist contributions on rationality highlighted by
@rutherfordInstitutionalist2013 and @yonayStruggle2001. At the same
time, our results bring to light additional contributions not covered in
these accounts, thereby opening avenues for further inquiry. Of course,
some important works remain absent because they were published as books
rather than journal articles. This limitation suggests that extending
the corpus to include books would be a worthwhile direction for future
research.

Second, a key property of groupings produced by unsupervised methods is
that they bring together documents that share cognitive content without
presupposing agreement. The texts clustered together address the same
objects or problems, but they may do so in divergent, and sometimes
opposing, ways. As a result, our methods make it possible to identify
sites of resistance to dominant models or ideas. What emerges most
clearly are the objects that attract sustained attention; within those
sites, one can then examine who endorses, revises, or contests
particular ways of treating them. This feature opens the way to a more
"symmetrical" historical analysis [@bloor1976], one that gives
analytical weight not only to intellectual "winners" but also to those
whose positions did not ultimately prevail.

Finally, these methods are also "discovery tools." While they can be
used to confirm or challenge existing claims in the history and
philosophy of economics, they also help identify patterns that have so
far been absent---or only marginally present---in the historical
literature. We have briefly pointed to some of these patterns above. By
making available an [interactive
application](https://019adac8-81d4-aa0e-808c-08861c261fd2.share.connect.posit.cloud/)
to explore our results, we hope to encourage readers to pursue their own
paths of discovery within the corpus.

[^1]: The bibliometric communities, identified through network analysis,
    could also be called clusters. But we opted for "communities", a
    term often used in network analysis, in order to distinguish them
    from the "semantic clusters".

[^2]: To be clear, we don't think that quantitative methods are only
    helpful for very large corpora. However, it is where their surplus
    value may appear as the most obvious.

[^3]: The application is available here:
    [[https://019adac8-81d4-aa0e-808c-08861c261fd2.share.connect.posit.cloud/]{.underline}](https://019adac8-81d4-aa0e-808c-08861c261fd2.share.connect.posit.cloud/)

[^4]: One of the main challenges for a quantitative history of economics
    is to move beyond reliance on proprietary digital libraries and to
    actively develop open, historically inclusive corpora. This includes
    incorporating materials produced in non-Anglophone countries and
    expanding the range of textual formats considered---such as books,
    book reviews, working papers, and conference proceedings.

[^5]: The Elsevier API allows users to retrieve the full text of
    Elsevier journals such as the *European Economic Review*, provided
    that they have institutional access to the relevant issues.

[^6]: ISTEX allows us to retrieve economics journals not available
    through JSTOR or Elsevier API, such as the *Journal of Economic
    Theory* and to access specific issues of Elsevier journals for which
    we lack institutional access (e.g., the *European Economic review*
    before 1997). For more detailed information on the collection of
    data, see the appendix.

[^7]: Bibliometric and textual data themselves have a history; they are
    "made by institutions, through human processes"
    [@guldiDangerous2023, 34]. Whether digital or material, archives
    are shaped by "distortions" and \"occlusions\", and the processes
    through which they are constituted are themselves worthy subjects of
    historical investigation [@dastonSciences2012].

[^8]: The programming dimension of such computational approaches enable
    iterative feedback between analysis and corpus cleaning
    [@nelsonComputational2020]; critical scrutiny can therefore be
    continuously exercised at each stage of the research "pipeline"
    [@leeRole2020].

[^9]: Indeed, most textual methods are designed to identify
    commonalities within texts that share a specific linguistic
    structure. Hence, the same topic discussed by two documents in two
    different languages will likely not be identified as related because
    linguistic differences mask underlying semantic similarity**.**

[^10]: This filtering draws on JSTOR's and Scopus' own classifications,
    supplemented by some additional filtering from ourselves. Despite
    these safeguards, a perfectly clean restriction to research articles
    was not feasible, and some residual "non-article" items likely
    remain.

[^11]: See the appendix for more information on the matching process.

[^12]: Adding these other outlets would pose additional challenges. For
    both working papers and, above all, books, no large-scale databases
    provide comprehensive full texts or complete reference lists. In
    addition, working papers raise the problem of potential double
    counting, as they may eventually be published in economic journals.

[^13]: We did not filter journals by language a priori. Indeed, many
    non-anglo-saxon journals also publish English articles at some more
    or less frequent occasions. It was thus easier to filter by language
    a posteriori and at the document level, once articles were
    collected.

[^14]: Our goal here is not to provide the reader with extensive details
    on what these models are and how we use them (see the appendix for
    additional details and references), but rather to provide general
    intuitions about the use of LLMs, to understand the building of our
    corpus.

[^15]: Henceforth, "similarity" between sentences or documents refers to
    cosine similarity, defined as the cosine of the angle between two
    vectors in the embedding space.

[^16]: [Moreover, the texts used to train these models are not primarily
    academic articles in economics. This means that there may be
    important gaps between the general language patterns the model has
    learned and the specific vocabulary, concepts, and writing practices
    of our "domain" [see e.g. @zhangEconBERT2025].]{.mark}

[^17]: We initially tested a symmetric two-year window. However,
    particularly in the early periods, this specification resulted in
    substantial volatility in average usage of the terms "rational" and
    "rationality", thereby increasing the number of "noisy" sentences
    (i.e. sentences not clearly related to rationality or tied to highly
    specific issues). Conversely, longer windows would reduce the
    advantages of our historical approach, as they would blur temporal
    variation too much, especially given the rapid growth of the corpus
    after the 1960s.

[^18]: [Centroids are widely used in the literature on \"semantic
    change" to represent the average embedding of a temporal slice or a
    cluster of a corpus [@montanelliSurvey2024]. We adopt the centroid
    rather than the medoid (i.e. the observed sentences whose embedding
    is closest to all others in the set), as the centroid smooths over
    idiosyncratic variation across sentences, whereas the medoid may be
    disproportionately influenced by a single atypical example. While
    the medoid is an embedding of a real sentence and is easily
    interpretable, it is very easy to compute the closest embeddings
    from the centroid (see]{.mark} @tbl-illustrative_sentences).

[^19]: [The choice of the 1% quantile reflects a trade-off between false
    positives and false negatives. We observed that a more restrictive
    threshold (e.g., 0.5%) excludes many sentences that obviously deal
    with rationality in economics, whereas a more permissive threshold
    (e.g. 2%) includes sentences that are too distant from our core
    focus, particularly in earlier periods. The 1% threshold therefore
    appeared as a reasonable compromise. Moreover, a moderate number of
    false positives does not substantially threaten the analysis, since
    such sentences are likely to be classified as "noise" by the HDBSCAN
    algorithm.]{.mark}

[^20]: The "articles-corpus" only starts in 1960, because the
    bibliographic data from WoS are too limited prior to this date to be
    reliably used.

[^21]: "Unsupervised" does not mean that the modeller has no influence
    on the output. The analyst must choose a particular model and its
    parameters and these choices embed methodological priors about the
    types of patterns the procedure is likely to reveal. For instance,
    one crucial parameter in many unsupervised models is the number of
    categories that will emerge from the algorithm. We detail and
    justify the different parameters chosen for our methods in the
    appendix.

[^22]: See @simonsLarge2026 for a discussion of using LLMs with
    unsupervised or supervised methods in the history and philosophy of
    science.

[^23]: That does not mean, however, that an unsupervised algorithm can
    be applied blindly to historical questions: a substantial part of
    our effort has consisted in adapting the method to our historical
    data, especially to accommodate the growth of the corpus over time.

[^24]: The eight-year window for bibliometric communities follows
    established practice in the quantitative history of economics
    [@claveauMacrodyanmics2016], which is generally between 5 and 10
    years [@abramoAssessing2011]. In our case, economics being a
    social science with longer citation spans of life
    [@lariviereLongterm2008; @aistleitnerCitation2019], and our
    object of study spanning across multiple decades, a longer time
    window than 5 years is favored while preserving more granularity
    than a 10-year one.

[^25]: Refer to the appendix for details.

[^26]: We don't use overlapping windows in this case, notably for
    computational reasons: finding HDSBCAN clusters on a set of tens of
    thousands of sentences is much more computationally intensive than
    finding bibliometric communities for at most five thousands of
    articles.

[^27]: Intertemporal semantic clusters are thus composed of several
    intra-decade clusters that have been aggregated together. The
    [[interactive
    application]{.underline}](https://019adac8-81d4-aa0e-808c-08861c261fd2.share.connect.posit.cloud/)
    represents all these intra-decade clusters and their integration
    into intertemporal clusters. Refer to the appendix for details.

[^28]: One step in the discovery and interpretive process is often the
    assignment of "labels" to clusters in order to facilitate the
    interpretation of visualizations.

[^29]: Of course, as in any historical inquiry of this kind, we are not
    entirely protected from selective emphasis, all the more so given
    that the scope of our study is too broad to summarize every pattern
    revealed by our results. Other scholars could have, at various
    junctures, pursued different interpretive directions on the basis of
    the same indicators (especially most similar sentences and
    articles). The publication of the [interactive
    application](https://019adac8-81d4-aa0e-808c-08861c261fd2.share.connect.posit.cloud/)
    we used to explore the results thus serves as an exercise in
    transparency and---in addition to being, we hope, useful for
    historians of economic thought more generally---allows readers to
    assess the robustness and limits of our narrative.

[^30]: However, because we focus on English, published articles, our
    clusters are biased toward American journals, notably in the first
    decades.

[^31]: Some years earlier, @mitchellRationality1910[97] already
    pushed forward similar claims, regretting that "few economists have
    regarded the study of psychology as a necessary part of the
    equipment of their work," often relying on "tacit preconceptions"
    rather than to seek to "psychologists to gain a knowledge of the
    mind and its modes of operation."

[^32]: See closest sentences to the "Utility Theory" cluster's centroid.

[^33]: Machlup's position was that even if a "goodly portion of all
    business behavior may be non-rational, thoughtless, [or] blindly
    repetitive" [-@machlupMarginal1946, 520], questionnaire evidence
    and empirical findings more generally did not demonstrate the
    failure of marginal theory when properly interpreted. In a similar
    defense of profit maximization, Leonid @hurwiczTheory1946[110]
    first acknowledged that it was not "inconceivable that business is
    run more by routine than by rationality," but argued that behavior
    may appear irrational or merely "routine" from the standpoint of a
    purely static theory that ignores uncertainty, while proving fully
    "rational" once uncertainty and long-run effects are taken into
    account [see also @herfeldTheories2018].

[^34]: The cluster "Firm Theory & Entrepreneur" nevertheless remained a
    site for critiques of profit maximization. During the 1960s and
    1970s, contributions that proposed alternative frameworks for
    explaining firms' decisions were highly cited [such as
    @simonTheories1959] or appeared among closest articles from
    centroid [like @winterSatisficing1971].

[^35]: This grouping of sentences in the 1970s actually took its origins
    in the cluster "Utility Theory" (which ended in the 1960s) with a
    focus on welfare economics.

[^36]: This highlights a key caveat of our methods. Because these
    methods foreground statistically "significant" patterns and
    indicators' prevalence, they are not always well suited to tracing
    and interpreting the origins of a concept or theory with the care
    that close historical study and archival research provide.
