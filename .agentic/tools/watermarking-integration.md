# Build Watermarking Integration

**Purpose**: Add subtle attribution to build artifacts (not source code).

The watermark is encoded and only appears in final build outputs (HTML, JS bundles, binaries, etc.). It's not visible in source code that AI agents see.

---

## How It Works

1. **During build**: Script injects encoded watermark into artifacts
2. **Encoding**: Base64 + reverse + obfuscation (not searchable)
3. **Location**: HTML comments, JS comments, binary metadata
4. **Verification**: Can decode to verify attribution

---

## Integration Examples

### Web Apps (React, Vue, Next.js, etc.)

**package.json**:
```json
{
  "scripts": {
    "build": "vite build && bash .agentic/tools/watermark.sh inject dist/index.html",
    "build:nextjs": "next build && bash .agentic/tools/watermark.sh inject .next/index.html"
  }
}
```

### CLI Tools (Go, Rust, etc.)

**Makefile**:
```makefile
build:
	go build -o myapp
	bash .agentic/tools/watermark.sh inject myapp
	
release:
	cargo build --release
	bash .agentic/tools/watermark.sh inject target/release/myapp
```

### Python Apps

**build.sh**:
```bash
#!/bin/bash
python setup.py build
bash .agentic/tools/watermark.sh inject dist/myapp.py
```

### Mobile Apps (React Native)

**package.json**:
```json
{
  "scripts": {
    "build:ios": "react-native bundle && bash .agentic/tools/watermark.sh inject ios/main.jsbundle",
    "build:android": "react-native bundle && bash .agentic/tools/watermark.sh inject android/app/build/index.android.bundle"
  }
}
```

---

## Verification

**Check if artifact has watermark**:
```bash
bash .agentic/tools/watermark.sh verify dist/index.html
```

**Decode watermark manually**:
```bash
# Extract encoded string from artifact
grep -o "__X[^Y]*Y__" dist/index.html

# Decode it
bash .agentic/tools/watermark.sh decode "__X[encoded]Y__"
```

---

## Important Notes

1. **Not in source code**: Watermark only goes into build artifacts
2. **Not visible to AI**: Source code remains clean for AI agents
3. **Encoded**: Not searchable with simple grep
4. **Optional**: Only if you want attribution in final products
5. **Automated**: Integrates into existing build process

---

## License Compliance

This watermarking supports the framework's licensing:
- Free tier: Attribution visible (optional but recommended)
- Paid tier: Can skip watermarking if preferred
- Kipinä Software: Free use, watermarking optional

---

## See Also

- Framework license: `LICENSE` file
- Build automation: Project-specific build scripts

