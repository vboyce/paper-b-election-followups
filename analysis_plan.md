# Analysis plan notes

## Make list of analyses to consider
all from 2016 election study that could apply here
all existing for 2020 and 2024 existing analysis pipeline


## Robustness checks
* for 2020 -- what happens if only the first task is considered (event and one other task done in different orders) 
* possible filter for comp questions -- at least check accuracy numbers here
* responses to recall (graphics only, possibly in supplement)
* SPR & maze exclusion options based on RT plausibility 
* log versus normal scale for RT, do we residualize? 
* excluding entire participants where people left their sliders at 0 (all of them)
* not applying the US citizen/resident exclusion (applied in the main set for both studies)
* "maximally attentive" subset for reading tasks: correct comprehension answer, every critical-trial word 180-5000 ms, Maze accuracy >= threshold (`attentive` set in descriptives.Rmd)


## Exclusions
* native english speaker
* exclude what seem to be repeat responses from the same person
* exclude what seem to be bot responses (how can we tell)
* exclude responses that seem to be from non US citizens/residents (how can we tell)

## Analysis

### graphical analysis of 
* event probabilities (& check what polls / prediction markets said at the time)
* cloze completions (all categories)
* SPR/Maze RTs 1st sentence
* SPR/Maze RTs 2nd sentence
* maze-race sentences --2020 only--
* demographics (awareness)  

### models

should use item-level ranef (single shot, so no subject level?)

* have frequent 3 way variable (she/he/they) to work with -- need to decide how to code for models. 


