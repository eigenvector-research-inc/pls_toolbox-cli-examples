# PLS_Toolbox CLI Examples

This repository contains **MATLAB code examples** demonstrating how to use the [**PLS_Toolbox**](https://eigenvector.com/software/pls-toolbox/) from the **command line interface (CLI)** rather than the graphical user interface (GUI).

These examples are intended to help users automate common chemometric workflows, integrate PLS_Toolbox models into custom scripts, and explore scripting capabilities for process analytics, spectroscopy, and multivariate modeling.

---

## Overview

The **PLS_Toolbox CLI** provides full access to modeling, preprocessing, validation, and prediction tools directly from MATLAB scripts or the command window.  
This repository illustrates example of:
- How to load and preprocess data sets programmatically  
- How to build and validate models (e.g., PCA, PLS, PLS-DA, PCR, etc.)  
- How to export and reuse models  
- How to perform predictions from the command line  
- How to script diviner from the command line
- Any script that showcases applications of the PLS_Toolbox  

Each example is self-contained and includes explanatory comments.

---

## Proposed Repository Structure

pls_toolbox-cli-examples/

	-README.md               		# This file
	-examples/
		├── pca_example.m           # Example: PCA from CLI
		├── pls_regression.m        # Example: PLS regression with preprocessing
		├── plda_classification.m   # Example: PLS-DA classification
		├── preprocessing_demo.m    # Example: SNV, MSC, derivatives
		├── batch_prediction.m      # Example: automated predictions using saved model
		└── …
	-data/
		└── example_dataset.mat     # Example data for demonstration
	-utils/
		└── helper_functions.m      # Shared helper functions


---

## ⚙️ Requirements

- **MATLAB R2020b or later**
- **PLS_Toolbox v9.0+** (or compatible Eigenvector version)
- Optional: **Eigenvector Solo+MIA** for standalone deployment examples

Make sure the PLS_Toolbox is correctly installed and licensed before running the scripts.

---

## ▶️ Usage

Clone the repository and add it to your MATLAB path:

```matlab
git clone https://github.com/<your-username>/pls_toolbox-cli-examples.git
addpath(genpath('pls_toolbox-cli-examples'));

Then run an example, for instance:

run('examples/pls_regression.m')

Each script contains detailed comments explaining the CLI syntax, required inputs, and key parameters.

⸻

🧠 Learning Resources
	•	[**PLS_Toolbox Wiki**](https://www.eigenvectordocs.com/index.php?title=Software_User_Guide)
	•	[**Eigenvector Research Resources**](https://eigenvector.com/resources/)
	•	[**MATLAB Scripting Guide**](https://www.mathworks.com/help/matlab/learn_matlab/scripts.html)

⸻

🤝 Contributing

Contributions are welcome!
If you have your own CLI examples or improvements:
	1.	Fork the repository
	2.	Create a feature branch (git checkout -b my-example)
	3.	Commit your changes with clear comments
	4.	Submit a pull request

All contributions should follow MATLAB best practices and include sufficient comments for reproducibility.

⸻

📄 License

This repository is distributed under the MIT License.
Please note that PLS_Toolbox is a commercial product by Eigenvector Research, Inc., and its use requires a valid license.

⸻

🧩 Acknowledgments

Developed and maintained by EVRI
in collaboration with the Eigenvector Research community.

Special thanks to the chemometrics and spectroscopy community for promoting reproducible, script-based analytical workflows.
