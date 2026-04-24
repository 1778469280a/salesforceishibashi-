# AGENTS.md

## Salesforce DX 项目

**类型**: Salesforce DX（非 Git 管理部署）
**包**: `force-app/main/default`（API v65.0）
**目标组织**: 配置在 `.sf/config.json`（默认别名: `ishibashi`）

## 开发者命令

```bash
# 部署到目标组织
sf project deploy start --manifest manifest/package.xml --target-org ishibashi

# 部署源代码（DX 推荐方式）
sf project deploy start --source --target-org ishibashi

# 在浏览器中打开组织
sf org open --target-org ishibashi
```

## 部署流程

- **CI**: GitHub Actions（`.github/workflows/deploy.yml`）在推送到 `master` 分支时部署到测试沙盒
- **清单**: 使用 `manifest/package.xml`（非源代码部署）
- **源代码追踪**: Salesforce 源代码追踪（非 Git 基于）

## 忽略文件

`.forceignore` 中列出的文件:
- `package.xml`
- LWC 配置: `jsconfig.json`, `.eslintrc.json`
- `**/__tests__/**`

## 主要目录

- `force-app/main/default/classes/` - Apex 类
- `force-app/main/default/lwc/` - Lightning Web 组件
- `force-app/main/default/aura/` - Aura 组件
- `force-app/main/default/pages/` - Visualforce 页面

## 注意事项

- 仓库内无本地 Apex 测试运行器；在 Salesforce 组织中运行测试或使用 `sf apex run tests`
- 仓库内无 LWC 的 ESLint/Prettier 配置；依赖 Salesforce 工具