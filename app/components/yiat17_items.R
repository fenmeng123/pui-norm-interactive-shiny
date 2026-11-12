# Chinese Y-IAT (Hou, 2013), as recorded in the study data dictionary.
# English IAT-R (Mak & Young, 2020), matched by original item number.
yiat17_items <- data.frame(
  original_number = c(1L, 2L, 3L, 5L, 6L, 8L, 10L, 11L, 12L, 13L, 14L, 15L, 16L, 17L, 18L, 19L, 20L),
  wording = c(
    "觉得上网的时间比你预期的要长吗？",
    "会因为上网忽略自己要做的事情吗？",
    "更愿意上网而不是和亲密的朋友待在一起吗？",
    "生活中朋友、家人会抱怨我上网时间太长吗？",
    "因为上网影响学习了吗？",
    "因为上网影响到我的日常生活了吗？",
    "会因为心情不好去上网吗？",
    "在一次上网后会渴望下一次上网吗？",
    "如果无法上网你会觉得生活空虚无聊吗？",
    "会因为别人打搅我上网发脾气吗？",
    "会上网到深夜不去睡觉吗？",
    "在离开网络后会想着网上的事情吗？",
    "在上网时会对自己说：“就再玩一会吗？”",
    "会想方法减少上网时间而最终失败吗？",
    "会对人隐瞒我上网多长时间吗？",
    "宁愿上网而不愿意和朋友们出去玩吗？",
    "会因为不能上网变得烦躁不安，喜怒无常，而一旦能上网就不会这样吗？"
  ),
  wording_en = c(
    "How often do you find that you use Internet activities longer than you intended?",
    "How often do you neglect self-management (e.g., cleaning and eating) to spend more time on Internet activities?",
    "How often do you prefer the excitement from Internet activities, more than that from the interactions with your family members or friends?",
    "How often do family members or friends complain to you about the amount of time you spend on Internet activities?",
    "How often does your work or study performance suffer because of your Internet leisure activities (e.g., online games)?",
    "How often do you fail to concentrate on your work or study because of your Internet activities?",
    "How often do you attempt to escape from your real life with soothing thoughts of Internet activities?",
    "How often do you find the next chance for Internet activities when you have to stop using it for a period (e.g., in class or meeting)?",
    "How often do you anticipate that life without Internet activities would be empty and boring?",
    "How often do you act annoyed if someone bothers you while you are concentrating on your Internet activities?",
    "How often do you lose sleep due to late night Internet activities?",
    "How often do you feel preoccupied with or fantasize about Internet activities even you are actually not doing them?",
    "How often do you tell yourself that extending the time for Internet activities should not be a problem?",
    "How often do you try to cut down the amount of time you spend on Internet activities but fail?",
    "How often do you try to hide your time spending on Internet activities from your family members of friends?",
    "How often do you prefer spending time on Internet activities, rather than going out with other people?",
    "How often do you feel depressed when you could not do Internet activities?"
  ),
  stringsAsFactors = FALSE
)
yiat17_choices <- c("几乎没有" = "1", "偶尔" = "2", "有时" = "3", "经常" = "4", "总是" = "5")
yiat17_choices_en <- c("Almost never" = "1", "Occasionally" = "2", "Sometimes" = "3", "Often" = "4", "Always" = "5")
