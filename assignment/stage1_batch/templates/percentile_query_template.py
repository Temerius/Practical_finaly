#!/usr/bin/env python3
"""
Spark Query Template
Вычисление 95-го перцентиля event_duration по device_type по дням
"""

# TODO: Реализовать запрос для вычисления перцентилей
# Требования:
# - 95-й перцентиль event_duration по device_type по дням
# - Исключить outliers (3 стандартных отклонения от среднего)
# - Только device_type с >= 500 событий в день
