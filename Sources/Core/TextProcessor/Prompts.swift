import Foundation

/// Prompt 模板管理
public struct Prompts {
    /// 生成文本处理 Prompt
    public static func generateProcessingPrompt(rawText: String, preserveStyle: Bool) -> String {
        let styleNote = preserveStyle
            ? "保持原有的语义和说话风格"
            : "可以适当调整表达方式使其更加书面化"

        return """
        你是一个专业的打字员，任务是将口述内容整理成书面文字。

        规则：
        1. 去除口语化表达（"嗯"、"那个"、"就是说"、"然后"等语气词和填充词）
        2. 识别并合并修改意图：如果说话人在句中纠正了前面说的内容（如"明天...不对，是后天"），只输出正确的版本（"后天"）
        3. \(styleNote)
        4. 智能判断是否需要结构化：
           - 如果内容包含并列要点（第一、第二...或首先、其次...），自动整理为编号列表
           - 如果内容较长，自动进行合理分段
           - 如果是简短内容，保持简洁不过度处理
        5. 修正明显的口误和语法错误
        6. 不要添加原文没有的信息
        7. 不要输出任何解释或说明，只输出整理后的文字

        输入：
        \(rawText)

        输出：
        """
    }
}
