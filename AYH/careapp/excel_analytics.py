

import io
import logging
from typing import Optional

import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots

logger = logging.getLogger(__name__)

ALLOWED_EXTENSIONS = ('.xlsx', '.xls')
MAX_ROWS = 50_000
MAX_COLUMNS = 50


def _is_numeric(series: pd.Series) -> bool:
    return pd.api.types.is_numeric_dtype(series) and series.notna().any()


def _is_categorical(series: pd.Series, max_unique=50) -> bool:
    if series.dtype == object or str(series.dtype) == 'category':
        return series.nunique() <= max_unique
    if pd.api.types.is_numeric_dtype(series):
        return False
    if pd.api.types.is_datetime64_any_dtype(series):
        return series.nunique() <= max_unique
    return series.nunique() <= max_unique


def _safe_name(s):
    return str(s).strip() or '(unnamed)'


def build_charts_and_summary(df: pd.DataFrame) -> dict:
    """
    Build Plotly chart HTML and summary stats from a DataFrame.
    Returns dict: charts=[{title, html}], summary_table=[...], row_count, column_count, error.
    """
    out = {
        'charts': [],
        'summary_table': [],
        'row_count': len(df),
        'column_count': len(df.columns),
        'error': None,
    }
    if df.empty or len(df.columns) == 0:
        out['error'] = 'The sheet has no data or no columns.'
        return out

    df = df.head(MAX_ROWS)
    cols = list(df.columns)[:MAX_COLUMNS]
    df = df[cols].copy()

    # Summary table: column name, dtype, non-null count, sample unique values
    for col in cols:
        s = df[col].dropna()
        summary_row = {
            'column': _safe_name(col),
            'dtype': str(df[col].dtype),
            'non_null': int(df[col].notna().sum()),
            'nulls': int(df[col].isna().sum()),
            'unique': int(df[col].nunique()),
        }
        if _is_numeric(df[col]):
            summary_row['min'] = round(float(df[col].min()), 2) if df[col].notna().any() else None
            summary_row['max'] = round(float(df[col].max()), 2) if df[col].notna().any() else None
            summary_row['mean'] = round(float(df[col].mean()), 2) if df[col].notna().any() else None
        out['summary_table'].append(summary_row)

    # Chart 1: Numeric columns - distribution (histogram) or bar if few unique
    numeric_cols = [c for c in cols if _is_numeric(df[c])]
    chart_idx = [0]
    first_chart = [True]  # include Plotly.js in first chart so it loads before any chart

    def _add_chart(title, fig):
        cid = chart_idx[0]
        chart_idx[0] += 1
        include_js = first_chart[0]
        first_chart[0] = False
        html = fig.to_html(full_html=False, include_plotlyjs='cdn' if include_js else False, div_id=f'chart-{cid}')
        out['charts'].append({'title': title, 'html': html})

    for col in numeric_cols[:6]:  # limit number of charts
        try:
            s = df[col].dropna()
            if len(s) == 0:
                continue
            n_unique = s.nunique()
            col_name = _safe_name(col)
            if n_unique <= 20:
                vc = s.value_counts().sort_index()
                fig = px.bar(
                    x=vc.index.astype(str),
                    y=vc.values,
                    title=f'Distribution of "{col_name}"',
                    labels={'x': col_name, 'y': 'Count'},
                )
            else:
                fig = px.histogram(
                    x=s,
                    title=f'Distribution of "{col_name}"',
                    labels={'x': col_name, 'y': 'Count'},
                    nbins=min(40, n_unique),
                )
            fig.update_layout(
                template='plotly_white',
                margin=dict(t=50, b=40, l=50, r=30),
                height=320,
                font=dict(size=11),
                xaxis_tickangle=-45,
            )
            _add_chart(f'Numeric: {col_name}', fig)
        except Exception as e:
            logger.warning('Chart failed for column %s: %s', col, e)

    # Chart 2: Categorical and datetime columns - bar (value_counts)
    cat_cols = [c for c in cols if c not in numeric_cols and _is_categorical(df[c])]
    for col in cat_cols[:6]:
        try:
            ser = df[col].dropna()
            if len(ser) == 0:
                continue
            # Convert datetime to str for stable value_counts display
            if pd.api.types.is_datetime64_any_dtype(ser):
                ser = ser.astype(str)
            vc = ser.value_counts().head(20)
            col_name = _safe_name(col)
            fig = px.bar(
                x=vc.index.astype(str),
                y=vc.values,
                title=f'Count by "{col_name}"',
                labels={'x': col_name, 'y': 'Count'},
            )
            fig.update_layout(
                template='plotly_white',
                margin=dict(t=50, b=40, l=50, r=30),
                height=320,
                font=dict(size=11),
                xaxis_tickangle=-45,
            )
            _add_chart(f'Category: {col_name}', fig)
        except Exception as e:
            logger.warning('Chart failed for column %s: %s', col, e)

    # Chart 3: If we have at least 2 numeric columns - correlation heatmap
    if len(numeric_cols) >= 2:
        try:
            sub = df[numeric_cols[:15]].dropna(how='all')
            if len(sub) >= 2:
                corr = sub.corr()
                fig = px.imshow(
                    corr,
                    title='Correlation (numeric columns)',
                    labels=dict(x='', y='', color='Correlation'),
                    color_continuous_scale='RdBu',
                    zmin=-1,
                    zmax=1,
                    aspect='auto',
                )
                fig.update_layout(
                    template='plotly_white',
                    margin=dict(t=50, b=80, l=120, r=30),
                    height=400,
                    font=dict(size=10),
                )
                _add_chart('Correlation heatmap', fig)
        except Exception as e:
            logger.warning('Correlation chart failed: %s', e)

    # Chart 4: First two numeric columns as scatter (if both numeric)
    if len(numeric_cols) >= 2:
        try:
            xcol, ycol = numeric_cols[0], numeric_cols[1]
            sub = df[[xcol, ycol]].dropna()
            if len(sub) >= 2:
                fig = px.scatter(
                    sub,
                    x=xcol,
                    y=ycol,
                    title=f'Scatter: {_safe_name(xcol)} vs {_safe_name(ycol)}',
                )
                fig.update_layout(
                    template='plotly_white',
                    margin=dict(t=50, b=40, l=50, r=30),
                    height=350,
                    font=dict(size=11),
                )
                _add_chart('Scatter (first two numeric)', fig)
        except Exception as e:
            logger.warning('Scatter chart failed: %s', e)

    # Fallback: if no charts yet, build one from first column
    if len(out['charts']) == 0 and len(cols) > 0:
        try:
            col = cols[0]
            ser = df[col].dropna().astype(str)
            vc = ser.value_counts().head(20)
            col_name = _safe_name(col)
            fig = px.bar(
                x=vc.index,
                y=vc.values,
                title=f'Count by "{col_name}"',
                labels={'x': col_name, 'y': 'Count'},
            )
            fig.update_layout(template='plotly_white', margin=dict(t=50, b=40, l=50, r=30), height=320, font=dict(size=11), xaxis_tickangle=-45)
            _add_chart(f'Count: {col_name}', fig)
        except Exception as e:
            logger.warning('Fallback chart failed: %s', e)

    return out


def read_excel_to_dataframe(file_or_path) -> pd.DataFrame:
    """Read first sheet of Excel file (file object or path) into DataFrame."""
    path_or_file = file_or_path
    name = ''
    if hasattr(path_or_file, 'read'):
        path_or_file.seek(0)
        name = getattr(path_or_file, 'name', '') or ''
    else:
        name = str(path_or_file)
    engine = 'xlrd' if name.lower().endswith('.xls') else 'openpyxl'
    if hasattr(file_or_path, 'read'):
        file_or_path.seek(0)
        df = pd.read_excel(file_or_path, engine=engine)
    else:
        df = pd.read_excel(file_or_path, engine=engine)
    return df


def process_uploaded_excel(file) -> dict:
    """
    Process an uploaded Excel file. file is Django UploadedFile.
    Returns same dict as build_charts_and_summary; on read error sets error and empty charts.
    """
    out = {
        'charts': [],
        'summary_table': [],
        'row_count': 0,
        'column_count': 0,
        'error': None,
        'sheet_name': None,
    }
    try:
        name = getattr(file, 'name', '') or ''
        if not name.lower().endswith(('.xlsx', '.xls')):
            out['error'] = 'Only .xlsx and .xls files are allowed.'
            return out
        df = read_excel_to_dataframe(file)
        if df.empty:
            out['error'] = 'The Excel file has no data in the first sheet.'
            return out
        out['sheet_name'] = df.columns.name or 'Sheet1'
        result = build_charts_and_summary(df)
        out.update(result)
        return out
    except Exception as e:
        logger.exception('Excel processing failed')
        out['error'] = str(e)
        return out
