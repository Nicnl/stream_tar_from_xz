package main

import (
	"archive/tar"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
)

func getXzUncompressedSize(filePath string) (int64, error) {
	// Execute the xz -l --robot command and parse out the uncompressed size
	cmd := exec.Command("xz", "-l", "--robot", filePath)
	output, err := cmd.Output()
	if err != nil {
		return 0, fmt.Errorf("failed to execute xz command: %w", err)
	}

	// Parse the output to find the "file" line
	lines := strings.Split(string(output), "\n")
	for _, line := range lines {
		if strings.HasPrefix(line, "file") {
			// Split by whitespace/tabs and get the 5th field (index 4)
			fields := strings.Fields(line)
			if len(fields) < 5 {
				return 0, fmt.Errorf("unexpected xz output format")
			}

			// The 5th field is the uncompressed size
			size, err := strconv.ParseInt(fields[4], 10, 64)
			if err != nil {
				return 0, fmt.Errorf("failed to parse uncompressed size: %w", err)
			}
			return size, nil
		}
	}

	return 0, fmt.Errorf("could not find file information in xz output")
}

func main() {
	// Obtenir le chemin du dossier à décompresser en stream
	if len(os.Args) < 2 {
		panic("usage: stream_tar_from_xz <path_to_directory> [optional: output_file]")
	}

	dirPath := os.Args[1]
	fmt.Fprintln(os.Stderr, "Processing directory:", dirPath)

	// Déterminer le nombre de threads xz à utiliser
	xzNumThreads := runtime.NumCPU()
	if envProcs := os.Getenv("XZ_NUM_THREADS"); envProcs != "" {
		nbProcs, err := strconv.Atoi(envProcs)
		if err == nil && nbProcs > 0 {
			xzNumThreads = nbProcs
		}
	}
	fmt.Fprintln(os.Stderr, "Using", xzNumThreads, "xz threads (customize using XZ_NUM_THREADS environment variable)")

	// Préparer le tar de sortie
	outputDestination := os.Stdout
	if len(os.Args) > 2 {
		outputFile, err := os.Create(os.Args[2])
		if err != nil {
			panic(errors.Join(err, errors.New("[c4f3e1b1] erreur lors de la création du fichier de sortie")))
		}
		defer outputFile.Close()
		outputDestination = outputFile
	}

	w := tar.NewWriter(outputDestination)
	defer w.Close()

	// Parcourir le dossier
	filepath.Walk(dirPath, func(path string, fi os.FileInfo, err error) error {
		// Skip own root
		if path == dirPath {
			return nil
		}

		fmt.Fprintln(os.Stderr, path[len(dirPath)+1:])

		// Générer le header depuis le fichier
		header, err := tar.FileInfoHeader(fi, fi.Name())
		if err != nil {
			panic(errors.Join(err, errors.New("[3a02a579] erreur lors de la génération du tar.Header depuis le fichier")))
		}

		// Mettre le chemin relatif dans le header
		isXz := !fi.IsDir() && strings.HasSuffix(strings.ToLower(fi.Name()), ".xz")

		if fi.IsDir() {
			header.Name = path[len(dirPath)+1:] + "/"
		} else {
			header.Name = path[len(dirPath)+1:]
		}

		// Si c'est un dossier, on écrit le header et on passe au suivant
		if fi.IsDir() {
			err = w.WriteHeader(header)
			if err != nil {
				panic(errors.Join(err, errors.New("[d62acf81] erreur lors de l'écriture du header du dossier dans le tar.Writer")))
			}
			return nil
		}

		var xzDecompressCmd *exec.Cmd
		if isXz {
			// Pour écrire le header du fichier du tar, on a besoin de connaître la taille décompressée
			uncompressedFileSize, err := getXzUncompressedSize(path)
			if err != nil {
				panic(errors.Join(err, errors.New("[a70d8e38] erreur lors de la récupération de la taille décompressée xz")))
			}
			fmt.Fprintln(os.Stderr, "  - uncompressed size:", uncompressedFileSize)

			// Préparer la commande de décompression
			xzDecompressCmd = exec.Command("xz", "-d", "-c", "--threads", strconv.Itoa(xzNumThreads), path)
			xzDecompressCmd.Stdout = w

			// Si on arrive ici, c'est qu'on est prêt à décompresser le flux
			header.Name = header.Name[:len(header.Name)-3] // Enlever le .xz
			header.Size = uncompressedFileSize
		}

		// Écrire le header et le contenu
		err = w.WriteHeader(header)
		if err != nil {
			panic(errors.Join(err, errors.New("[d62acf81] erreur lors de l'écriture du header du dossier dans le tar.Writer")))
		}

		if isXz {
			// Si fichier XZ, on a juste à lancer la commande
			err = xzDecompressCmd.Run()
			if err != nil {
				panic(errors.Join(err, errors.New("[ef48d364] erreur lors de la décompression xz")))
			}
		} else {
			// Ouvrir le fichier
			f, err := os.Open(path)
			if err != nil {
				panic(errors.Join(err, errors.New("[a8d58e7b] erreur lors de l'ouverture du fichier")))
			}
			defer f.Close()

			// Copier le contenu du fichier dans le tar.Writer
			_, err = io.Copy(w, f)
			if err != nil {
				panic(errors.Join(err, errors.New("[542d541f] erreur lors de la copie du contenu du fichier dans le tar.Writer")))
			}
		}

		// Flush au cas où
		err = w.Flush()
		if err != nil {
			panic(errors.Join(err, errors.New("[8b32cbaf] erreur lors du flush du tar.Writer")))
		}

		return nil
	})
}
