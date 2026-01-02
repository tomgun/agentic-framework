# Stack profile: Python ML project

Quick guidance for initializing a machine learning project with Python and this framework.

## Tech choices

### Language & runtime
- Python 3.10+ recommended
- Package management: `pip` + `requirements.txt` or `poetry`
- Virtual env: `venv` or `conda`

### ML frameworks
- Training: `scikit-learn`, `pytorch`, or `tensorflow`
- Data: `pandas`, `numpy`
- Visualization: `matplotlib`, `seaborn`
- Experiment tracking: `mlflow`, `wandb`, or `tensorboard`

### Testing
- Test framework: `pytest`
- Data validation: `great_expectations` or custom
- Model validation: threshold tests (accuracy, f1-score, etc.)
- Test command: `pytest tests/`

### Project structure (typical)
```
/data
  /raw          # Original immutable data
  /processed    # Transformed data
/models         # Trained model artifacts
/notebooks      # Jupyter notebooks (exploration)
/src
  /data         # Data processing
  /features     # Feature engineering
  /models       # Model definitions
  /evaluation   # Metrics and evaluation
/tests
/experiments    # Experiment configs/logs
```

## STACK.md template sections

```markdown
## Setup
- Python: 3.10+
- Install: `pip install -r requirements.txt`
- Or: `poetry install`
- Virtual env: `python -m venv venv && source venv/bin/activate`

## Run
- Train model: `python src/train.py --config experiments/config.yml`
- Evaluate: `python src/evaluate.py --model models/model_v1.pkl`
- Inference: `python src/predict.py --input data/test.csv`

## Test
- Run: `pytest tests/`
- Coverage: `pytest --cov=src tests/`

## Data
- Raw data location: data/raw/
- Preprocessing: `python src/data/preprocess.py`
- Versioning: DVC or git-lfs for large files

## Experiments
- Tracking: mlflow (or wandb)
- Server: `mlflow ui` (localhost:5000)
```

## Test strategy guidance

### Unit tests
- Test data transformations
- Test feature engineering logic
- Test model prediction interface (with dummy model)

```python
def test_preprocess_handles_missing_values():
    df = pd.DataFrame({'a': [1, None, 3]})
    result = preprocess(df)
    assert result['a'].isna().sum() == 0
```

### Model tests
- Threshold tests: "model achieves >80% accuracy on validation set"
- Invariance tests: "model predictions unchanged for feature X permutation"
- Regression tests: "model predictions match known good outputs"

```python
def test_model_accuracy_threshold():
    model = load_model('models/model_v1.pkl')
    X_val, y_val = load_validation_data()
    accuracy = model.score(X_val, y_val)
    assert accuracy > 0.80, f"Model accuracy {accuracy} below threshold"
```

### Integration tests
- Full pipeline: data load → preprocess → train → evaluate
- API tests if serving model via REST

## NFR considerations

For `spec/NFR.md`:
- **Performance**: Inference latency, throughput, batch vs online
- **Data quality**: Missing value handling, outlier detection
- **Model performance**: Minimum accuracy/F1/RMSE thresholds
- **Reproducibility**: Random seed, version pinning, deterministic training
- **Fairness**: Bias detection, fairness metrics if applicable

## Feature tracking

Map ML capabilities to features:
- F-0001: Data ingestion pipeline
- F-0002: Feature engineering (PCA, normalization, etc.)
- F-0003: Model training (algorithm X)
- F-0004: Model evaluation (metrics Y, Z)
- F-0005: Model deployment (API or batch)

## Common gotchas

- **Reproducibility**: Pin all dependencies, set random seeds, version data
- **Data leakage**: Ensure train/test split before any preprocessing
- **Notebook code**: Move production code from notebooks to `src/`, keep notebooks for exploration only
- **Model versioning**: Track which model version is deployed
- **Large files**: Use DVC, git-lfs, or document external storage

## Acceptance criteria patterns

ML features need specific acceptance criteria:
- Performance metrics: "Model achieves F1 > 0.85 on holdout set"
- Inference time: "Prediction completes in <100ms for single example"
- Data quality: "Pipeline handles missing values in columns A, B, C"
- Reproducibility: "Same data + seed produces identical model"

## References

- ML testing: https://madewithml.com/courses/mlops/testing/
- ML project structure: https://drivendata.github.io/cookiecutter-data-science/
- DVC for data versioning: https://dvc.org/

