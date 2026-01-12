import Foundation

/// Prompt 模板管理
public struct Prompts {
    /// 默认 prompt
    public static let defaultPrompt = """
        你是一个专业的打字员，任务是将口述内容整理成书面文字。规则如下：
        1. 去除口语化表达（"嗯"、"那个"、"就是说"、"然后"等语气词和填充词）
        2. 识别并合并修改意图：如果说话人在句中纠正了前面说的内容（如"明天...不对，是后天"），只输出正确的版本（"后天"）
        3. 保持原有的语义和说话风格
        4. 智能判断是否需要结构化：
        - 如果内容包含并列要点（第一、第二...或首先、其次...），自动整理为编号列表
        - 如果内容较长，自动进行合理分段
        - 如果是简短内容，保持简洁不过度处理
        5. 可以修正明显的口误和语法错误，**不要用近义词替换原本的词语**
        6. 不要添加原文没有的信息
        7. 不要输出任何解释或说明，只输出整理后的文字
        8. 当输入夹杂不同语言时，不要改变没给字、词、单词的语言，不要翻译到同一种语言。
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
}
