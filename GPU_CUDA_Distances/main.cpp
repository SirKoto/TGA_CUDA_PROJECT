#include <iostream>
#include <stdlib.h>

#include <cuda_runtime.h>
#include <vector_types.h>
#include "GlobalHeader.h"
#include "loader.h"

extern "C" int runCuda(embed_t * norms, embedV_t * model, int32_t numRows, int32_t queryTermPos,int32_t N);




int main(int argc, char* argv[]) {

	if (argc != 2) {
		std::cout << "Needs a file to load" << std::endl;
		return 0;
	}

	std::vector<std::string> words;
	embed_t* norms;
	embedV_t* embeddings;
	size_t numElems;

	int res = loader::loadData(argv[1], numElems, words, norms, embeddings);

	if (res) {
		std::cout << "Embedings loaded" << std::endl;
	}
	else {
		std::cout << "ERROR::EMBEDINGS NOT LOADED!" << std::endl;
		return 1;
	}

	std::string word;
	int returnCode = 0;
	std::cout << "Enter word to look for similarities" << std::endl;
	while (returnCode == 0 && std::cin >> word) {
		// Search word
		unsigned int idx = loader::binary_search(words, word);
		if (idx == -1) {
			std::cout << "Could not find word!!!!" << std::endl;
			continue;
		}
		
		std::cout << "Found word \"" << word << "\" in position " << idx << std::endl;

		returnCode  = runCuda(norms, embeddings, numElems, idx, 5);
		std::cout << "Enter word to look for similarities" << std::endl;
	}


	// free data
	loader::freeData(norms, embeddings);

	return returnCode;
}
