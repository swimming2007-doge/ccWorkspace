"""
Validator - 数据校验工具

功能：
- 数据格式校验
- URL 校验
- 配置校验
"""

import re
from typing import Any, List, Optional, Dict
from dataclasses import dataclass


@dataclass
class ValidationResult:
    """校验结果"""
    valid: bool
    errors: List[str]

    def __bool__(self) -> bool:
        return self.valid


def validate_url(url: str) -> ValidationResult:
    """
    校验 URL 格式

    Args:
        url: URL 字符串

    Returns:
        ValidationResult
    """
    errors = []

    if not url:
        errors.append("URL 不能为空")
    elif not isinstance(url, str):
        errors.append("URL 必须是字符串")
    else:
        url_pattern = re.compile(
            r'^https?://'  # http:// 或 https://
            r'(?:(?:[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?\.)+[A-Z]{2,6}\.?|'  # 域名
            r'localhost|'  # localhost
            r'\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})'  # IP
            r'(?::\d+)?'  # 端口
            r'(?:/?|[/?]\S+)$', re.IGNORECASE)

        if not url_pattern.match(url):
            errors.append(f"URL 格式无效: {url}")

    return ValidationResult(valid=len(errors) == 0, errors=errors)


def validate_non_empty_string(value: Any, field_name: str) -> ValidationResult:
    """
    校验非空字符串

    Args:
        value: 待校验值
        field_name: 字段名

    Returns:
        ValidationResult
    """
    errors = []

    if value is None:
        errors.append(f"{field_name} 不能为 None")
    elif not isinstance(value, str):
        errors.append(f"{field_name} 必须是字符串")
    elif not value.strip():
        errors.append(f"{field_name} 不能为空字符串")

    return ValidationResult(valid=len(errors) == 0, errors=errors)


def validate_positive_integer(value: Any, field_name: str) -> ValidationResult:
    """
    校验正整数

    Args:
        value: 待校验值
        field_name: 字段名

    Returns:
        ValidationResult
    """
    errors = []

    if value is None:
        errors.append(f"{field_name} 不能为 None")
    elif not isinstance(value, int):
        errors.append(f"{field_name} 必须是整数")
    elif value <= 0:
        errors.append(f"{field_name} 必须是正整数")

    return ValidationResult(valid=len(errors) == 0, errors=errors)


def validate_list(value: Any, field_name: str,
                  item_validator: Optional[callable] = None) -> ValidationResult:
    """
    校验列表

    Args:
        value: 待校验值
        field_name: 字段名
        item_validator: 列表项校验函数

    Returns:
        ValidationResult
    """
    errors = []

    if value is None:
        errors.append(f"{field_name} 不能为 None")
    elif not isinstance(value, list):
        errors.append(f"{field_name} 必须是列表")
    elif item_validator:
        for i, item in enumerate(value):
            result = item_validator(item)
            if not result.valid:
                errors.extend([f"{field_name}[{i}]: {e}" for e in result.errors])

    return ValidationResult(valid=len(errors) == 0, errors=errors)


def validate_config(config: Dict[str, Any],
                    required_keys: List[str]) -> ValidationResult:
    """
    校验配置字典

    Args:
        config: 配置字典
        required_keys: 必需的键列表

    Returns:
        ValidationResult
    """
    errors = []

    if not isinstance(config, dict):
        errors.append("配置必须是字典类型")
    else:
        for key in required_keys:
            if key not in config:
                errors.append(f"缺少必需配置项: {key}")
            elif config[key] is None:
                errors.append(f"配置项 {key} 的值不能为 None")

    return ValidationResult(valid=len(errors) == 0, errors=errors)


class DataValidator:
    """数据校验器类"""

    def __init__(self):
        self.errors: List[str] = []

    def validate(self, data: Any, rules: Dict[str, Any]) -> bool:
        """
        根据规则校验数据

        Args:
            data: 待校验数据
            rules: 校验规则

        Returns:
            是否通过校验
        """
        self.errors = []

        for field, rule in rules.items():
            value = data.get(field) if isinstance(data, dict) else getattr(data, field, None)

            if rule.get("required", False) and value is None:
                self.errors.append(f"{field} 是必需的")
                continue

            if value is not None:
                if "type" in rule and not isinstance(value, rule["type"]):
                    self.errors.append(f"{field} 类型错误，期望 {rule['type']}")
                if "min" in rule and value < rule["min"]:
                    self.errors.append(f"{field} 不能小于 {rule['min']}")
                if "max" in rule and value > rule["max"]:
                    self.errors.append(f"{field} 不能大于 {rule['max']}")
                if "pattern" in rule and not re.match(rule["pattern"], str(value)):
                    self.errors.append(f"{field} 格式不匹配 {rule['pattern']}")

        return len(self.errors) == 0

    def get_errors(self) -> List[str]:
        """获取错误列表"""
        return self.errors
