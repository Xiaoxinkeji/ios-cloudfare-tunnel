import Foundation

enum TunnelError: Error, Equatable {
    case unauthorized
    case forbidden
    case tunnelNotFound
    case invalidConfiguration(reason: String)
    case networkUnavailable
    case rateLimited(retryAfter: TimeInterval?)
    case serverUnavailable
    case decodingFailed
    case conflict
    case unknown(message: String)
}

extension TunnelError {
    var title: String {
        switch self {
        case .unauthorized: return "无法验证身份"
        case .forbidden: return "没有操作权限"
        case .tunnelNotFound: return "Tunnel 不存在"
        case .invalidConfiguration: return "配置无效"
        case .networkUnavailable: return "网络连接不可用"
        case .rateLimited: return "请求过于频繁"
        case .serverUnavailable: return "服务暂时不可用"
        case .decodingFailed: return "返回数据异常"
        case .conflict: return "当前状态已变化"
        case .unknown: return "发生未知错误"
        }
    }

    var message: String {
        switch self {
        case .unauthorized:
            return "请检查 API Token 是否正确，或是否已经过期。"
        case .forbidden:
            return "当前账号没有操作这个 Tunnel 的权限，请检查 Account / Zone / Token scope。"
        case .tunnelNotFound:
            return "没有找到对应的 Tunnel，请检查 Tunnel ID 是否填写正确。"
        case .invalidConfiguration(let reason):
            return "请检查配置内容。\(reason)"
        case .networkUnavailable:
            return "当前网络不可用，稍后重试即可。"
        case .rateLimited(let retryAfter):
            if let retryAfter {
                return "请求太频繁，请在 \(Int(retryAfter)) 秒后再试。"
            }
            return "请求太频繁，请稍后再试。"
        case .serverUnavailable:
            return "Cloudflare 服务或控制后端暂时不可用，请稍后重试。"
        case .decodingFailed:
            return "服务返回了无法识别的数据格式，请稍后再试或检查接口版本。"
        case .conflict:
            return "Tunnel 当前状态已发生变化，页面会自动刷新。"
        case .unknown(let message):
            return message
        }
    }

    var shouldAutoRetry: Bool {
        switch self {
        case .networkUnavailable, .rateLimited, .serverUnavailable:
            return true
        default:
            return false
        }
    }

    var suggestedRetryDelay: TimeInterval {
        switch self {
        case .rateLimited(let retryAfter):
            return retryAfter ?? 3
        case .networkUnavailable:
            return 2
        case .serverUnavailable:
            return 2
        default:
            return 0
        }
    }
}
