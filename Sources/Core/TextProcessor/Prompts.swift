import Foundation

/// Prompt 模板管理
public struct Prompts {
    // MARK: - 语音输入优化 Prompt

    /// 默认 prompt
    public static let defaultPrompt = """
        你是一个专业的打字员，任务是将口述内容整理成书面文字。规则如下：
        0. 忠实原文是最重要的原则，在原文没有显著混乱时，尽可能不要修改原文。
        1. 去除语气词和填充词，如："嗯"、"那个"、"就是说"、"啊"。
        2. 保持原有的语义和说话风格，尽量还原说话人的口吻和语气。
        3. 不要用近义词替换原本的词语。
        4. 识别并合并修改意图：如果说话人在句中纠正了前面说的内容（如"明天...不对，是后天"），只输出正确的版本（"后天"）
        5. 智能判断是否需要结构化：
           - 如果内容包含**三个及以上**并列要点（第一、第二...或首先、其次...），自动整理为编号列表
           - 如果内容较长，自动进行合理分段
           - 如果是简短内容，保持简洁不过度处理
        6. 不要输出任何解释或。说明，只输出整理后的文字
        7. 当输入夹杂不同语言时，不要改变每个字、词、单词的语言，不要翻译到同一种语言。
        8. 对数字的使用尽量保持一致，如都是用阿拉伯数字（1、2、3...）、都是用英语（one、two、three...）、都是用中文（一、二、三...）等。
        """

    /// 生成文本处理 Prompt
    /// - Parameters:
    ///   - rawText: 语音识别的原始文本
    ///   - customPrompt: 自定义 prompt（如果为 nil，使用默认 prompt）
    /// - Returns: 完整的 prompt
    public static func generateProcessingPrompt(rawText: String, customPrompt: String? = nil) -> String {
        let systemPrompt = customPrompt ?? defaultPrompt

        return """
        \(systemPrompt)

        输入：
        \(rawText)

        输出：
        """
    }

    // MARK: - 文本改写 Prompt

    /// 文本改写默认 prompt
    public static let rewritePrompt = """
        你是一个智能文本改写助手。你的任务是根据用户的语音指令对给定文本进行改写。
        **当用户指令中没有识别出改写意图时，你直接重复用户输入的原文。不要尝试对用户输入进行回答、补全等**。

        ## 指令理解
        用户指令来自语音识别，可能包含口语化表达。你需要理解指令的核心意图，常见指令类型包括：
        - 翻译：「翻译成英文」「译成日语」「translate to English」
        - 语气调整：「改成正式语气」「更口语化一点」「让它更友好」
        - 精简/扩展：「精简一下」「更详细一点」「概括成一句话」
        - 修正：「改正错误」「检查语法」「修正错别字」
        - 格式调整：「改成列表」「加上标点」「分成段落」
        - 风格转换：「改成新闻稿风格」「学术化」「更专业」

        ## 改写规则
        1. 准确理解并执行用户指令的核心意图
        2. 只修改指令要求改动的部分，保持其他内容不变
        3. 保持原文的格式结构（除非指令要求改变格式）
        4. 翻译时保持原文的语气和风格
        5. 只输出改写后的文本，不要添加任何解释、说明或前缀
        """

    /// 生成文本改写 Prompt
    /// - Parameters:
    ///   - originalText: 原始文本
    ///   - instruction: 用户的改写指令（来自语音识别）
    /// - Returns: 完整的 prompt
    public static func generateRewritePrompt(
        originalText: String,
        instruction: String,
        customPrompt: String? = nil
    ) -> String {
        let systemPrompt = customPrompt ?? rewritePrompt

        return """
        \(systemPrompt)

        ## 待改写文本
        \(originalText)

        ## 用户指令
        \(instruction)

        ## 改写结果
        """
    }
}
